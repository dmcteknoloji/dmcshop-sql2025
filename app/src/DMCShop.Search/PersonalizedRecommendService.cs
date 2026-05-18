using System.Globalization;
using System.Text;
using DMCShop.Data;
using DMCShop.Domain.Abstractions;
using DMCShop.Domain.Dtos;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace DMCShop.Search;

/// <summary>
/// Senaryo 5: Vector + Graph hibrit kişiselleştirilmiş öneri.
///
/// Akış:
///   1) Müşterinin son N siparişindeki ürünlerin vector embedding'ini al
///   2) .NET tarafında centroid hesapla (basit aritmetik ortalama)
///   3) VECTOR_SEARCH ile centroid'e en yakın 20 candidate
///   4) Filter: müşterinin zaten satın aldığı ürünleri çıkar
///   5) graph.purchased ile her candidate için distinct buyer sayısı (social proof)
///   6) Hibrit skor: distance + 1/(1+social) — küçük = daha iyi
///
/// Centroid neden .NET'te? SQL Server 2025 RTM'de VECTOR için AVG aggregate'i public
/// değil; .NET float[] toplama + bölme ile O(N×dim) tek pass yeterli.
/// </summary>
public sealed class PersonalizedRecommendService(DMCShopDbContext db, IEmbeddingProvider provider)
{
    /// <summary>Müşterinin son N satın aldığı ürünün centroid'ini al ve hibrit öneri üret.</summary>
    public async Task<(PersonalizationContext Context, IReadOnlyList<PersonalizedRecommendation> Items)>
        RecommendAsync(int customerId, int basisLimit = 8, int topK = 10, CancellationToken cancellationToken = default)
    {
        // 1) Müşteri adı + son N siparişindeki ürün ID + embedding'leri
        var conn = (SqlConnection)db.Database.GetDbConnection();
        var opened = conn.State != System.Data.ConnectionState.Open;
        if (opened) await conn.OpenAsync(cancellationToken);

        try
        {
            string customerName = await GetCustomerNameAsync(conn, customerId, cancellationToken);

            var (basisIds, vectors) = await GetCustomerVectorsAsync(conn, customerId, basisLimit, provider.Name, cancellationToken);
            if (basisIds.Count == 0)
            {
                return (new PersonalizationContext(customerId, customerName, 0, Array.Empty<int>(), provider.Dimensions),
                        Array.Empty<PersonalizedRecommendation>());
            }

            var centroid = Centroid(vectors);
            var centroidLiteral = ToVectorLiteral(centroid);

            // 2) VECTOR_SEARCH + filter (zaten alınmış değil) + graph social score (LEFT JOIN)
            var items = await VectorSearchWithGraphAsync(conn, centroidLiteral, customerId,
                                                         provider.Dimensions, provider.Name, topK, cancellationToken);

            return (new PersonalizationContext(customerId, customerName, basisIds.Count, basisIds, provider.Dimensions),
                    items);
        }
        finally
        {
            if (opened) await conn.CloseAsync();
        }
    }

    private static async Task<string> GetCustomerNameAsync(SqlConnection conn, int customerId, CancellationToken ct)
    {
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT full_name FROM shop.customer WHERE customer_id = @id";
        cmd.Parameters.Add(new SqlParameter("@id", customerId));
        var name = (string?)await cmd.ExecuteScalarAsync(ct);
        return name ?? $"#{customerId}";
    }

    private static async Task<(List<int> Ids, List<float[]> Vectors)> GetCustomerVectorsAsync(
        SqlConnection conn, int customerId, int basisLimit, string providerName, CancellationToken ct)
    {
        var col = providerName == "openai" ? "embedding_openai_1536" : "embedding_ollama_768";

        await using var cmd = conn.CreateCommand();
        cmd.CommandText = $"""
            SELECT TOP (@n)
                ol.product_id,
                CAST({col} AS NVARCHAR(MAX)) AS vec_json
            FROM   shop.[order]      o
            JOIN   shop.order_line   ol ON ol.order_id   = o.order_id
            JOIN   vector.product_embedding pe ON pe.product_id = ol.product_id
            WHERE  o.customer_id = @cid
              AND  pe.{col} IS NOT NULL
            ORDER BY o.order_date DESC, ol.product_id;
            """;
        cmd.Parameters.Add(new SqlParameter("@cid", customerId));
        cmd.Parameters.Add(new SqlParameter("@n",   basisLimit));

        var ids = new List<int>();
        var vecs = new List<float[]>();
        await using var rdr = await cmd.ExecuteReaderAsync(ct);
        while (await rdr.ReadAsync(ct))
        {
            ids.Add(rdr.GetInt32(0));
            vecs.Add(ParseVectorJson(rdr.GetString(1)));
        }
        return (ids, vecs);
    }

    private static async Task<List<PersonalizedRecommendation>> VectorSearchWithGraphAsync(
        SqlConnection conn, string centroidLiteral, int customerId,
        int dim, string providerName, int topK, CancellationToken ct)
    {
        var col = providerName == "openai" ? "embedding_openai_1536" : "embedding_ollama_768";

        // VECTOR_SEARCH top 30 candidate → filter zaten alınmış olanlar →
        // graph'tan social count → hibrit skor ile TOP K
        var sql = $"""
            DECLARE @v VECTOR({dim}) = CAST(@centroid AS VECTOR({dim}));

            WITH hits AS (
                SELECT * FROM VECTOR_SEARCH(
                    TABLE      = vector.product_embedding,
                    COLUMN     = {col},
                    SIMILAR_TO = @v,
                    METRIC     = 'cosine',
                    TOP_N      = 30)
            ),
            unowned AS (
                SELECT h.product_id, h.distance
                FROM   hits h
                WHERE  NOT EXISTS (
                    SELECT 1
                    FROM   shop.[order]    o
                    JOIN   shop.order_line ol ON ol.order_id = o.order_id
                    WHERE  o.customer_id = @cid AND ol.product_id = h.product_id
                )
            ),
            social AS (
                SELECT u.product_id, u.distance,
                       (SELECT COUNT(DISTINCT pur.order_id)
                        FROM   graph.product_node pn,
                               graph.purchased    pur,
                               graph.customer_node c
                        WHERE  MATCH(c-(pur)->pn)
                          AND  pn.product_id = u.product_id) AS buyers
                FROM   unowned u
            )
            SELECT TOP (@k)
                s.product_id, p.sku, p.name, cat.name AS category_name,
                p.price, LEFT(p.description_tr, 120) AS preview,
                s.distance, s.buyers,
                CAST(s.distance + 1.0 / (1.0 + s.buyers) AS FLOAT) AS hybrid_score
            FROM   social s
            JOIN   shop.product          p   ON p.product_id   = s.product_id
            JOIN   shop.product_category cat ON cat.category_id = p.category_id
            ORDER BY hybrid_score ASC;
            """;

        await using var cmd = conn.CreateCommand();
        cmd.CommandText    = sql;
        cmd.CommandTimeout = 60;
        cmd.Parameters.Add(new SqlParameter("@centroid", centroidLiteral));
        cmd.Parameters.Add(new SqlParameter("@cid",      customerId));
        cmd.Parameters.Add(new SqlParameter("@k",        topK));

        var rows = new List<PersonalizedRecommendation>();
        await using var rdr = await cmd.ExecuteReaderAsync(ct);
        while (await rdr.ReadAsync(ct))
        {
            rows.Add(new PersonalizedRecommendation(
                ProductId:        rdr.GetInt32(0),
                Sku:              rdr.GetString(1),
                Name:             rdr.GetString(2),
                CategoryName:     rdr.GetString(3),
                Price:            rdr.GetDecimal(4),
                Preview:          rdr.IsDBNull(5) ? null : rdr.GetString(5),
                VectorDistance:   Convert.ToDouble(rdr.GetValue(6)),
                SocialBuyerCount: rdr.GetInt32(7),
                HybridScore:      Convert.ToDouble(rdr.GetValue(8))));
        }
        return rows;
    }

    /// <summary>Top N müşteri (sipariş sayısına göre) — Blazor sayfasında dropdown için.</summary>
    public async Task<List<(int CustomerId, string FullName, int OrderCount)>>
        TopCustomersAsync(int limit = 50, CancellationToken cancellationToken = default)
    {
        var conn = (SqlConnection)db.Database.GetDbConnection();
        var opened = conn.State != System.Data.ConnectionState.Open;
        if (opened) await conn.OpenAsync(cancellationToken);
        try
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = """
                SELECT TOP (@n) c.customer_id, c.full_name, COUNT(*) AS order_count
                FROM   shop.customer  c
                JOIN   shop.[order]   o ON o.customer_id = c.customer_id
                GROUP BY c.customer_id, c.full_name
                ORDER BY order_count DESC;
                """;
            cmd.Parameters.Add(new SqlParameter("@n", limit));

            var list = new List<(int, string, int)>();
            await using var rdr = await cmd.ExecuteReaderAsync(cancellationToken);
            while (await rdr.ReadAsync(cancellationToken))
                list.Add((rdr.GetInt32(0), rdr.GetString(1), rdr.GetInt32(2)));
            return list;
        }
        finally
        {
            if (opened) await conn.CloseAsync();
        }
    }

    // --------------------------------------------------------------------
    // Centroid + vector parse / literal yardımcıları
    // --------------------------------------------------------------------

    private static float[] Centroid(List<float[]> vectors)
    {
        if (vectors.Count == 0) throw new ArgumentException("vectors empty");
        var dim = vectors[0].Length;
        var sum = new double[dim];
        foreach (var v in vectors)
        {
            for (var i = 0; i < dim; i++) sum[i] += v[i];
        }
        var result = new float[dim];
        for (var i = 0; i < dim; i++) result[i] = (float)(sum[i] / vectors.Count);
        return result;
    }

    private static float[] ParseVectorJson(string json)
    {
        // VECTOR(N) -> NVARCHAR cast'i "[0.12, -0.34, ...]" formatı verir.
        // Hızlı parse — System.Text.Json yerine doğrudan span split.
        var trimmed = json.AsSpan().Trim();
        if (trimmed.Length > 0 && trimmed[0] == '[')           trimmed = trimmed[1..];
        if (trimmed.Length > 0 && trimmed[^1] == ']')          trimmed = trimmed[..^1];
        var span = trimmed;
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
