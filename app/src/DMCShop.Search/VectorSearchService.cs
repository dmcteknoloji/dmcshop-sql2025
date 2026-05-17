using System.Globalization;
using System.Text;
using DMCShop.Data;
using DMCShop.Domain.Abstractions;
using DMCShop.Domain.Dtos;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace DMCShop.Search;

public sealed class VectorSearchService(DMCShopDbContext db, IEmbeddingProvider provider)
{
    /// <summary>
    /// Query metnini provider üzerinden vector'e çevirir, DiskANN approximate
    /// kNN ile <paramref name="topK"/> ürün döner. Sonuçlar cosine distance'a
    /// göre artan sıralanır (0 = aynı vektör).
    /// </summary>
    public async Task<IReadOnlyList<ProductHit>> SearchAsync(string queryText, int topK = 5, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(queryText)) return [];

        var queryVector = await provider.EmbedAsync(queryText, cancellationToken);
        var vectorJson = ToVectorLiteral(queryVector);
        var column = ColumnFor(provider.Name);

        var sql = $"""
            DECLARE @v VECTOR({provider.Dimensions}) = CAST(@queryVector AS VECTOR({provider.Dimensions}));
            SELECT TOP (@topK) WITH APPROXIMATE
                vs.product_id              AS ProductId,
                p.sku                      AS Sku,
                p.name                     AS Name,
                cat.name                   AS CategoryName,
                p.price                    AS Price,
                LEFT(p.description_tr,120) AS Preview,
                vs.distance                AS Distance
            FROM VECTOR_SEARCH(
                TABLE      = vector.product_embedding,
                COLUMN     = {column},
                SIMILAR_TO = @v,
                METRIC     = 'cosine'
            ) AS vs
            JOIN shop.product          p   ON p.product_id   = vs.product_id
            JOIN shop.product_category cat ON cat.category_id = p.category_id
            ORDER BY vs.distance ASC;
            """;

        var rows = await db.Database
            .SqlQueryRaw<ProductHit>(
                sql,
                new SqlParameter("@queryVector", vectorJson),
                new SqlParameter("@topK", topK))
            .ToListAsync(cancellationToken);

        return rows;
    }

    /// <summary>
    /// Aynı sorgu için klasik LIKE araması — semantic search ile karşılaştırma.
    /// </summary>
    public Task<List<ProductHit>> LikeSearchAsync(string queryText, int topK = 10, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(queryText)) return Task.FromResult(new List<ProductHit>());

        const string sql = """
            SELECT TOP (@topK)
                p.product_id              AS ProductId,
                p.sku                     AS Sku,
                p.name                    AS Name,
                cat.name                  AS CategoryName,
                p.price                   AS Price,
                LEFT(p.description_tr,120) AS Preview,
                CAST(0.0 AS FLOAT)        AS Distance
            FROM shop.product          p
            JOIN shop.product_category cat ON cat.category_id = p.category_id
            WHERE p.name          LIKE N'%' + @q + N'%'
               OR p.description_tr LIKE N'%' + @q + N'%';
            """;

        return db.Database
            .SqlQueryRaw<ProductHit>(sql,
                new SqlParameter("@q", queryText),
                new SqlParameter("@topK", topK))
            .ToListAsync(cancellationToken);
    }

    private static string ColumnFor(string providerName) => providerName switch
    {
        "openai" => "embedding_openai_1536",
        "ollama" => "embedding_ollama_768",
        _ => throw new InvalidOperationException($"Bilinmeyen provider: {providerName}")
    };

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
