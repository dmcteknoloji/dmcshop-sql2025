using System.Globalization;
using System.Text;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace DMCShop.Cli.Commands;

/// <summary>
/// `dmcshop build-map` — embedding 2D haritası için JSON üretir.
/// Random projection (Johnson-Lindenstrauss; deterministic seed) ile
/// 768/1536D → 2D. Pure .NET, harici Python/numpy bağımlılığı yok.
///
/// Çıktı: wwwroot/embedding-map.json (Blazor static dosya olarak servis eder)
///
/// Kullanım:
///   dmcshop build-map                        — varsayılan 5000 örnek
///   dmcshop build-map --sample 2000          — 2K örnek
///   dmcshop build-map --output /tmp/map.json — özel yol
/// </summary>
internal sealed class BuildMapCommand(IServiceProvider sp)
{
    public async Task<int> RunAsync(string[] args)
    {
        using var scope = sp.CreateScope();
        var log    = scope.ServiceProvider.GetRequiredService<ILoggerFactory>().CreateLogger("build-map");
        var config = scope.ServiceProvider.GetRequiredService<IConfiguration>();

        var sample = ParseInt(args, "--sample", 5000);
        var output = ParseString(args, "--output",
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "DMCShop.Web", "wwwroot", "embedding-map.json"));
        output = Path.GetFullPath(output);

        var connStr = config.GetConnectionString("DMCShop")
            ?? throw new InvalidOperationException("ConnectionStrings:DMCShop yok");

        log.LogInformation("Embedding map üretimi: sample={Sample}, output={Output}", sample, output);

        // 1) Vector'leri çek
        await using var conn = new SqlConnection(connStr);
        await conn.OpenAsync();

        var sql = """
            SELECT TOP (@n)
                p.product_id, p.name, ISNULL(cat.name, '?') AS category,
                CAST(pe.embedding_ollama_768 AS NVARCHAR(MAX)) AS vec
            FROM   vector.product_embedding pe
            JOIN   shop.product             p   ON p.product_id   = pe.product_id
            JOIN   shop.product_category    cat ON cat.category_id = p.category_id
            WHERE  pe.embedding_ollama_768 IS NOT NULL
            ORDER BY (ABS(CHECKSUM(p.product_id, 42)) % 100000);   -- deterministic random sample
            """;

        await using var cmd = conn.CreateCommand();
        cmd.CommandText    = sql;
        cmd.CommandTimeout = 120;
        cmd.Parameters.Add(new SqlParameter("@n", sample));

        var ids = new List<int>(sample);
        var names = new List<string>(sample);
        var cats = new List<string>(sample);
        var vectors = new List<float[]>(sample);

        await using var rdr = await cmd.ExecuteReaderAsync();
        while (await rdr.ReadAsync())
        {
            ids.Add(rdr.GetInt32(0));
            names.Add(rdr.GetString(1));
            cats.Add(rdr.GetString(2));
            vectors.Add(ParseVector(rdr.GetString(3)));
        }

        if (vectors.Count == 0)
        {
            log.LogError("Hiç embedding bulunamadı. Önce 'dmcshop embed-products' çalıştırın.");
            return 4;
        }

        var dim = vectors[0].Length;
        log.LogInformation("Çekildi: {N} vector × {D} dim", vectors.Count, dim);

        // 2) Random projection — deterministic seed
        var rng = new Random(42);
        var px = new float[dim];
        var py = new float[dim];
        for (var i = 0; i < dim; i++)
        {
            px[i] = (float)(rng.NextDouble() * 2.0 - 1.0);
            py[i] = (float)(rng.NextDouble() * 2.0 - 1.0);
        }

        var coords = new (double X, double Y)[vectors.Count];
        for (var i = 0; i < vectors.Count; i++)
        {
            double sx = 0, sy = 0;
            var v = vectors[i];
            for (var j = 0; j < dim; j++)
            {
                sx += v[j] * px[j];
                sy += v[j] * py[j];
            }
            coords[i] = (sx, sy);
        }

        // 3) Normalize [-1, 1]
        var minX = coords.Min(c => c.X);
        var maxX = coords.Max(c => c.X);
        var minY = coords.Min(c => c.Y);
        var maxY = coords.Max(c => c.Y);
        var rangeX = maxX - minX == 0 ? 1 : maxX - minX;
        var rangeY = maxY - minY == 0 ? 1 : maxY - minY;

        var items = new List<object>(vectors.Count);
        for (var i = 0; i < vectors.Count; i++)
        {
            items.Add(new
            {
                id   = ids[i],
                name = names[i],
                cat  = cats[i],
                x    = Math.Round((coords[i].X - minX) / rangeX * 2.0 - 1.0, 4),
                y    = Math.Round((coords[i].Y - minY) / rangeY * 2.0 - 1.0, 4)
            });
        }

        var payload = new
        {
            generatedAt = DateTime.UtcNow.ToString("O"),
            method      = "random_projection_seeded_42",
            dim,
            count       = items.Count,
            items
        };

        Directory.CreateDirectory(Path.GetDirectoryName(output)!);
        await File.WriteAllTextAsync(output, JsonSerializer.Serialize(payload,
            new JsonSerializerOptions { WriteIndented = false }));

        log.LogInformation("Yazıldı: {Output} ({Size:N0} byte)",
            output, new FileInfo(output).Length);

        return 0;
    }

    private static float[] ParseVector(string json)
    {
        var span = json.AsSpan().Trim();
        if (span.Length > 0 && span[0] == '[')  span = span[1..];
        if (span.Length > 0 && span[^1] == ']') span = span[..^1];

        var count = 1;
        for (var i = 0; i < span.Length; i++) if (span[i] == ',') count++;
        var arr = new float[count];
        var idx = 0;
        var start = 0;
        for (var i = 0; i <= span.Length; i++)
        {
            if (i == span.Length || span[i] == ',')
            {
                arr[idx++] = float.Parse(span[start..i].Trim(), CultureInfo.InvariantCulture);
                start = i + 1;
            }
        }
        return arr;
    }

    private static int ParseInt(string[] args, string flag, int @default)
    {
        for (var i = 0; i < args.Length - 1; i++)
            if (args[i] == flag && int.TryParse(args[i + 1], out var v)) return v;
        return @default;
    }

    private static string ParseString(string[] args, string flag, string @default)
    {
        for (var i = 0; i < args.Length - 1; i++)
            if (args[i] == flag) return args[i + 1];
        return @default;
    }
}
