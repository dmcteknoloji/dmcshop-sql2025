using System.Diagnostics;
using System.Globalization;
using System.Text;
using DMCShop.Data;
using DMCShop.Domain.Abstractions;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace DMCShop.Cli.Commands;

internal sealed class EmbedProductsCommand(IServiceProvider sp)
{
    public async Task<int> RunAsync(string[] args)
    {
        using var scope = sp.CreateScope();
        var log      = scope.ServiceProvider.GetRequiredService<ILoggerFactory>().CreateLogger("embed-products");
        var db       = scope.ServiceProvider.GetRequiredService<DMCShopDbContext>();
        var provider = scope.ServiceProvider.GetRequiredService<IEmbeddingProvider>();

        var batchSize = ParseBatchSize(args);
        var (rangeStart, rangeEnd) = ParseRange(args);
        var onlyMissing = args.Contains("--only-missing");

        IQueryable<DMCShop.Domain.Entities.ProductEmbedding> q = db.ProductEmbeddings.AsNoTracking();
        if (rangeStart is { } s) q = q.Where(e => e.ProductId >= s);
        if (rangeEnd   is { } e2) q = q.Where(e => e.ProductId <= e2);

        // onlyMissing — bu provider için embedding henüz yazılmamış kayıtlar.
        // RAW SQL ile (kolon entity'de map'siz olduğu için)
        if (onlyMissing)
        {
            var col = provider.Name == "openai" ? "embedding_openai_1536" : "embedding_bge_1024";
            var sql = $"""
                SELECT product_id AS ProductId, source_text AS SourceText
                FROM   vector.product_embedding
                WHERE  {col} IS NULL
                  AND  product_id >= @s AND product_id <= @e
                ORDER BY product_id
                """;
            var missing = await db.Database.SqlQueryRaw<MissingRow>(sql,
                new Microsoft.Data.SqlClient.SqlParameter("@s", rangeStart ?? 0),
                new Microsoft.Data.SqlClient.SqlParameter("@e", rangeEnd   ?? int.MaxValue))
                .ToListAsync();
            var rowsM = missing.Select(m => new { m.ProductId, m.SourceText }).ToList();
            await RunBatchAsync(rowsM, batchSize, provider, db, log);
            return 0;
        }

        var rows = await q
            .Select(e => new { e.ProductId, e.SourceText })
            .OrderBy(e => e.ProductId)
            .ToListAsync();

        if (rows.Count == 0)
        {
            log.LogWarning("vector.product_embedding boş veya filtreyle hiç ürün eşleşmedi.");
            return 4;
        }

        await RunBatchAsync(rows.Select(r => new { r.ProductId, r.SourceText }).ToList(), batchSize, provider, db, log);
        return 0;
    }

    private async Task RunBatchAsync<T>(
        List<T> rows, int batchSize,
        IEmbeddingProvider provider, DMCShopDbContext db, ILogger log)
    {
        if (rows.Count == 0)
        {
            log.LogWarning("Eşleşen ürün yok.");
            return;
        }

        log.LogInformation("Embedding üretimi başlıyor — {Count} ürün, provider={Provider}/{Model}, batch={Batch}",
            rows.Count, provider.Name, provider.ModelName, batchSize);

        var sw = Stopwatch.StartNew();
        var written = 0;

        for (var offset = 0; offset < rows.Count; offset += batchSize)
        {
            var slice = rows.Skip(offset).Take(batchSize).ToList();
            var texts = slice.Select(r => (string)r!.GetType().GetProperty("SourceText")!.GetValue(r)!).ToList();
            var ids   = slice.Select(r => (int)r!.GetType().GetProperty("ProductId")!.GetValue(r)!).ToList();

            var vectors = await provider.EmbedBatchAsync(texts);

            for (var i = 0; i < slice.Count; i++)
            {
                var literal = ToVectorLiteral(vectors[i]);
                await UpdateEmbeddingAsync(db, provider, ids[i], literal);
                written++;
            }

            log.LogInformation("  {Done}/{Total} ({Pct:P0})", written, rows.Count, (double)written / rows.Count);
        }

        sw.Stop();
        log.LogInformation("Tamam — {Written} satır {Elapsed:N0} ms'de yazıldı (ortalama {Avg:N0} ms/ürün)",
            written, sw.ElapsedMilliseconds, sw.ElapsedMilliseconds / (double)Math.Max(1, written));

        log.LogInformation("DiskANN index'i (yeniden) oluşturuluyor…");
        await RecreateVectorIndexAsync(db, provider, log);
    }

    private sealed record MissingRow(int ProductId, string SourceText);

    private static (int? start, int? end) ParseRange(string[] args)
    {
        for (var i = 0; i < args.Length - 1; i++)
        {
            if (args[i] != "--range") continue;
            var parts = args[i + 1].Split('-');
            int? s = parts.Length > 0 && int.TryParse(parts[0], out var ps) ? ps : null;
            int? e = parts.Length > 1 && int.TryParse(parts[1], out var pe) ? pe : null;
            return (s, e);
        }
        return (null, null);
    }

    private static async Task RecreateVectorIndexAsync(DMCShopDbContext db, IEmbeddingProvider provider, ILogger log)
    {
        var (indexName, column) = provider.Name switch
        {
            "openai" => ("vix_pe_openai", "embedding_openai_1536"),
            "ollama" => ("vix_pe_bge", "embedding_bge_1024"),
            _ => throw new InvalidOperationException($"Bilinmeyen provider: {provider.Name}")
        };

        var dropSql = $"""
            IF EXISTS (SELECT 1 FROM sys.indexes
                       WHERE name = '{indexName}'
                         AND object_id = OBJECT_ID('vector.product_embedding'))
                DROP INDEX {indexName} ON vector.product_embedding;
            """;
        await db.Database.ExecuteSqlRawAsync(dropSql);

        var createSql = $"""
            CREATE VECTOR INDEX {indexName}
            ON vector.product_embedding ({column})
            WITH (METRIC = 'cosine', TYPE = 'DiskANN', MAXDOP = 4);
            """;
        await db.Database.ExecuteSqlRawAsync(createSql);
        log.LogInformation("Index {Index} hazır", indexName);
    }

    private static async Task UpdateEmbeddingAsync(DMCShopDbContext db, IEmbeddingProvider provider, int productId, string vectorLiteral)
    {
        var (column, updatedAtColumn, modelColumn) = provider.Name switch
        {
            "openai" => ("embedding_openai_1536", "openai_updated_at", "openai_model"),
            "ollama" => ("embedding_bge_1024",  "ollama_updated_at", "ollama_model"),
            _ => throw new InvalidOperationException($"Bilinmeyen provider: {provider.Name}")
        };

        var sql = $"""
            UPDATE vector.product_embedding
               SET {column}          = CAST(@v AS VECTOR({provider.Dimensions})),
                   {modelColumn}     = @model,
                   {updatedAtColumn} = SYSUTCDATETIME()
             WHERE product_id = @id;
            """;

        await db.Database.ExecuteSqlRawAsync(sql,
            new SqlParameter("@v",     vectorLiteral),
            new SqlParameter("@model", provider.ModelName),
            new SqlParameter("@id",    productId));
    }

    private static int ParseBatchSize(string[] args)
    {
        for (var i = 0; i < args.Length - 1; i++)
        {
            if (args[i] == "--batch" && int.TryParse(args[i + 1], out var n) && n > 0)
                return n;
        }
        return 16;
    }

    private static string ToVectorLiteral(float[] v)
    {
        var sb = new StringBuilder(v.Length * 8);
        sb.Append('[');
        for (var i = 0; i < v.Length; i++)
        {
            if (i > 0) sb.Append(',');
            sb.Append(v[i].ToString("R", CultureInfo.InvariantCulture));
        }
        sb.Append(']');
        return sb.ToString();
    }
}
