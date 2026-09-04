using System.Data.Common;
using System.Diagnostics;
using Microsoft.EntityFrameworkCore;

namespace DMCShop.Data;

public sealed record ServerInfo(string Version, string Edition, string UpdateLevel, DateTime? StartedUtc,
                               int CpuCount, int MemoryMb);

public sealed record TableStat(string Table, long Rows, long Kilobytes);

public sealed record VectorIndexInfo(string Name, string Kind, string Table);

/// <summary>Ad, ne olctugu, ilk kosu, en iyi kosu ve donen satir sayisi.</summary>
public sealed record Benchmark(string Name, string Explains, double FirstMs, double BestMs, long Rows);

/// <summary>
/// /olcum sayfasinin verisi. Hepsi salt okuma: sayac ve katalog gorunumleri
/// okunur, kiyas sorgulari da yalnizca SELECT calistirir. Demoda veri
/// degistirmemek icin DiskANN indeksini dusurup karsilastirma YAPILMAZ.
/// </summary>
public sealed class DatabaseMetricsService(DMCShopDbContext db)
{
    public async Task<ServerInfo> GetServerInfoAsync(CancellationToken ct = default)
    {
        const string sql = """
            SELECT CONVERT(nvarchar(50), SERVERPROPERTY(N'ProductVersion')),
                   CONVERT(nvarchar(80), SERVERPROPERTY(N'Edition')),
                   CONVERT(nvarchar(40), SERVERPROPERTY(N'ProductUpdateLevel')),
                   (SELECT sqlserver_start_time FROM sys.dm_os_sys_info),
                   (SELECT cpu_count FROM sys.dm_os_sys_info),
                   (SELECT CONVERT(int, physical_memory_kb / 1024) FROM sys.dm_os_sys_info)
            """;

        await using var cmd = await CommandAsync(sql, ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct)) return new ServerInfo("?", "?", "?", null, 0, 0);

        return new ServerInfo(
            r.IsDBNull(0) ? "?" : r.GetString(0),
            r.IsDBNull(1) ? "?" : r.GetString(1),
            r.IsDBNull(2) ? "-" : r.GetString(2),
            r.IsDBNull(3) ? null : r.GetDateTime(3),
            r.IsDBNull(4) ? 0 : r.GetInt32(4),
            r.IsDBNull(5) ? 0 : r.GetInt32(5));
    }

    public async Task<IReadOnlyList<TableStat>> GetTableStatsAsync(CancellationToken ct = default)
    {
        // Katalog adlari sunucu collation'inda, veritabani Turkish_..._UTF8:
        // birlestirirken COLLATE vermezsen "collation conflict" hatasi geliyor.
        const string sql = """
            SELECT OBJECT_SCHEMA_NAME(p.object_id) COLLATE DATABASE_DEFAULT + N'.' +
                   OBJECT_NAME(p.object_id) COLLATE DATABASE_DEFAULT AS tablo,
                   SUM(p.row_count)                  AS satir,
                   SUM(p.reserved_page_count) * 8    AS kb
            FROM   sys.dm_db_partition_stats p
            WHERE  p.index_id IN (0, 1)
                   AND OBJECTPROPERTY(p.object_id, 'IsUserTable') = 1
            GROUP BY p.object_id
            HAVING SUM(p.row_count) > 0
            ORDER BY SUM(p.reserved_page_count) DESC
            """;

        var list = new List<TableStat>();
        await using var cmd = await CommandAsync(sql, ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            list.Add(new TableStat(r.GetString(0), r.GetInt64(1), r.GetInt64(2)));
        return list;
    }

    public async Task<IReadOnlyList<VectorIndexInfo>> GetVectorIndexesAsync(CancellationToken ct = default)
    {
        // type = 8 sayisal; type_desc uzerinden LIKE aramak collation'a takiliyor.
        const string sql = """
            SELECT i.name COLLATE DATABASE_DEFAULT,
                   i.type_desc COLLATE DATABASE_DEFAULT,
                   OBJECT_SCHEMA_NAME(i.object_id) COLLATE DATABASE_DEFAULT + N'.' +
                   OBJECT_NAME(i.object_id) COLLATE DATABASE_DEFAULT
            FROM   sys.indexes i
            WHERE  i.type = 8
            """;

        var list = new List<VectorIndexInfo>();
        await using var cmd = await CommandAsync(sql, ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            list.Add(new VectorIndexInfo(r.GetString(0), r.GetString(1), r.GetString(2)));
        return list;
    }

    private static readonly (string Name, string Explains, string Sql)[] Suite =
    [
        ("VECTOR_SEARCH + DiskANN",
         "Kayitli bir embedding sonda vektor olarak veriliyor, yani Ollama cagrisi olmadan yalnizca motorun arama suresi olculuyor.",
         """
         DECLARE @q VECTOR(768) = (SELECT TOP (1) embedding_ollama_768
                                   FROM vector.product_embedding
                                   WHERE embedding_ollama_768 IS NOT NULL
                                   ORDER BY product_id);
         ;WITH hits AS (
             SELECT * FROM VECTOR_SEARCH(
                 TABLE = vector.product_embedding, COLUMN = embedding_ollama_768,
                 SIMILAR_TO = @q, METRIC = 'cosine', TOP_N = 10)
         )
         SELECT COUNT(*) FROM hits;
         """),

        ("Klasik LIKE taramasi",
         "Ayni katalogda metin eslesmesi. Dogal dil sorgusunda cogu zaman bos donuyor, karsilastirma bunun icin duruyor.",
         "SELECT COUNT(*) FROM shop.product WHERE name LIKE N'%klavye%' OR description_tr LIKE N'%klavye%';"),

        ("GRAPH: paylasilan cihaz",
         "Fraud sayfasinin ilk adimi. Ayni cihazi iki veya daha fazla musteri kullanmis mi.",
         """
         SELECT COUNT(*) FROM (
             SELECT cd.device_id
             FROM   shop.customer_device cd
             GROUP BY cd.device_id
             HAVING COUNT(DISTINCT cd.customer_id) >= 2) t;
         """),

        ("Siparis + satir birlestirme",
         "Vektor ve graf disinda kalan siradan is yuku; kiyas noktasi olsun diye duruyor.",
         """
         SELECT COUNT(*) FROM shop.[order] o
         JOIN shop.order_line ol ON ol.order_id = o.order_id;
         """),
    ];

    /// <summary>
    /// Her sorguyu ucer kez calistirir: ilk kosu soguk, en iyisi isinmis hali.
    /// Tek sayi yaniltici olurdu, ikisini birden gostermek daha durust.
    /// </summary>
    public async Task<IReadOnlyList<Benchmark>> RunBenchmarksAsync(CancellationToken ct = default)
    {
        var results = new List<Benchmark>(Suite.Length);

        foreach (var (name, explains, sql) in Suite)
        {
            double first = 0, best = double.MaxValue;
            long rows = 0;

            for (var run = 0; run < 3; run++)
            {
                ct.ThrowIfCancellationRequested();

                await using var cmd = await CommandAsync(sql, ct);
                var sw = Stopwatch.StartNew();
                var scalar = await cmd.ExecuteScalarAsync(ct);
                sw.Stop();

                var ms = sw.Elapsed.TotalMilliseconds;
                if (run == 0) first = ms;
                if (ms < best) best = ms;
                rows = scalar is null or DBNull ? 0 : Convert.ToInt64(scalar);
            }

            results.Add(new Benchmark(name, explains, first, best, rows));
        }

        return results;
    }

    public static string SqlOf(string name) =>
        Suite.FirstOrDefault(s => s.Name == name).Sql?.Trim() ?? string.Empty;

    private async Task<DbCommand> CommandAsync(string sql, CancellationToken ct)
    {
        var conn = db.Database.GetDbConnection();
        if (conn.State != System.Data.ConnectionState.Open)
            await conn.OpenAsync(ct);

        var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        cmd.CommandTimeout = 60;
        return cmd;
    }
}
