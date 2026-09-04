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

        // SQL Server 2025 notu (CU4'te yakalandi, CU8 / 17.0.4075.5 uzerinde
        // 2026-09-04'te yeniden olculdu, davranis ayni):
        //   - VECTOR_SEARCH'ün ürettiği kolonlara dış SELECT'ten doğrudan
        //     join içinde referans verirken kolon adı bulunamıyor; CTE
        //     üzerinden okumak güvenli.
        //   - TOP_N parametresi VECTOR_SEARCH içinde verilir; "TOP (N) WITH
        //     APPROXIMATE" syntax'ı RTM'de geçerli değil.
        var sql = $"""
            DECLARE @v VECTOR({provider.Dimensions}) = CAST(@queryVector AS VECTOR({provider.Dimensions}));
            WITH hits AS (
                SELECT * FROM VECTOR_SEARCH(
                    TABLE      = vector.product_embedding,
                    COLUMN     = {column},
                    SIMILAR_TO = @v,
                    METRIC     = 'cosine',
                    TOP_N      = @topK)
            )
            SELECT
                h.product_id              AS ProductId,
                p.sku                     AS Sku,
                p.name                    AS Name,
                cat.name                  AS CategoryName,
                p.price                   AS Price,
                LEFT(p.description_tr,120) AS Preview,
                h.distance                AS Distance
            FROM hits h
            JOIN shop.product          p   ON p.product_id   = h.product_id
            JOIN shop.product_category cat ON cat.category_id = p.category_id
            ORDER BY h.distance ASC;
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
    /// Hybrid retrieval — production RAG pattern:
    ///   1. Vector recall (DiskANN TOP_N) → semantic adaylar
    ///   2. Keyword recall (LIKE her token) → vector pool'un kaçırdığı tam-eşleşmeler
    ///   3. Union'da name + source_text overlap ile rerank
    /// Türkçe semantic uzayda nadir terim (örn. "Çağlar Özenç", "DMC") vector
    /// embed'i corpus'a uzak düşürebilir; salt vector tek başına yetmez. Keyword
    /// kanalı recall'u, vector kanalı semantic yakınlığı sağlar.
    ///   hybrid = distance - nameWeight*nameOverlap - bodyWeight*bodyOverlap
    /// Daha düşük skor daha iyi (cosine distance gibi).
    /// </summary>
    public async Task<IReadOnlyList<ProductHit>> HybridSearchAsync(
        string queryText,
        int topK = 5,
        int candidatePool = 0,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(queryText)) return [];

        // Default: topK * 20 — generic term'lerle dolu sorgularda (örn. "SQL Server kitabı")
        // hedef ürün pure-vector ranking'inde top-50'de olmayabilir; bu pool keyword
        // rerank şansı tanır. 50K kayıtta sub-second.
        // DiskANN approximate kNN — TOP_N hint'i; küçük değerler beam search'ü daraltır
        // ve hedef ürün indeksin "ana yol" dışındaysa kaybolabilir. Workshop demosunda
        // 50K kayıtta TOP_N=300 ~100ms; rerank candidate kalitesini garantiler.
        if (candidatePool <= 0) candidatePool = Math.Max(300, topK * 50);

        var queryVector = await provider.EmbedAsync(queryText, cancellationToken);
        var vectorJson = ToVectorLiteral(queryVector);
        var column = ColumnFor(provider.Name);

        var sql = $"""
            DECLARE @v VECTOR({provider.Dimensions}) = CAST(@queryVector AS VECTOR({provider.Dimensions}));
            WITH hits AS (
                SELECT * FROM VECTOR_SEARCH(
                    TABLE      = vector.product_embedding,
                    COLUMN     = {column},
                    SIMILAR_TO = @v,
                    METRIC     = 'cosine',
                    TOP_N      = @pool)
            )
            SELECT
                h.product_id              AS ProductId,
                p.sku                     AS Sku,
                p.name                    AS Name,
                cat.name                  AS CategoryName,
                p.price                   AS Price,
                LEFT(p.description_tr,120) AS Preview,
                LEFT(pe.source_text, 800) AS Body,
                h.distance                AS Distance
            FROM hits h
            JOIN shop.product          p   ON p.product_id   = h.product_id
            JOIN shop.product_category cat ON cat.category_id = p.category_id
            JOIN vector.product_embedding pe ON pe.product_id = h.product_id
            ORDER BY h.distance ASC;
            """;

        var candidates = await db.Database
            .SqlQueryRaw<HybridRow>(
                sql,
                new SqlParameter("@queryVector", vectorJson),
                new SqlParameter("@pool", candidatePool))
            .ToListAsync(cancellationToken);

        var qTokens = Tokenize(queryText).ToHashSet();

        // 3+ harfli token yoksa rerank fark yaratmaz — saf vector sonucu döner.
        if (qTokens.Count == 0)
        {
            return candidates.Take(topK)
                .Select(c => new ProductHit(c.ProductId, c.Sku, c.Name, c.CategoryName, c.Price, c.Preview, c.Distance))
                .ToList();
        }

        // Keyword recall — vector pool dışına düşen tam-eşleşmeleri yakala.
        // Distance bilinmiyor; placeholder olarak vector pool'un MAX distance'i
        // (en kötü vector aday) atanır. Keyword-only aday'lar rerank'te daha
        // agresif boost'la değerlendirilir.
        var vectorIds = candidates.Select(c => c.ProductId).ToHashSet();
        var keywordHits = await KeywordCandidatesAsync(qTokens, top: 50, cancellationToken);
        var poolMax = candidates.Count > 0 ? candidates[^1].Distance : 0.5;
        var byId = candidates.ToDictionary(c => c.ProductId);
        foreach (var k in keywordHits)
        {
            if (!byId.ContainsKey(k.ProductId))
                byId[k.ProductId] = k with { Distance = poolMax };
        }
        var merged = byId.Values.ToList();

        // Vector path: name'de match çoğu zaman generic ("elektronik") — body'deki
        // nadir terim eşleşmesini daha çok ödüllendirir.
        // Keyword path: LIKE zaten lexical garanti veriyor; daha agresif boost ile
        // pool dışı tam-eşleşmeleri öne çıkar.
        const double VectorNameWeight = 0.04;
        const double VectorBodyWeight = 0.06;
        // Keyword path body match'i nadir terim (DMC, Çağlar, SQL gibi tek-kelimelik
        // sorgular) için kritik — name'de geçmese bile source_text içinde varsa
        // sonucu öne çıkar.
        const double KeywordNameWeight = 0.10;
        const double KeywordBodyWeight = 0.15;

        var ranked = merged
            .Select(c =>
            {
                var nameTokens = Tokenize(c.Name);
                var bodyTokens = Tokenize(c.Body ?? string.Empty);
                int nameMatch = nameTokens.Intersect(qTokens).Count();
                int bodyMatch = bodyTokens.Intersect(qTokens).Count();
                bool fromKeyword = !vectorIds.Contains(c.ProductId);
                double nw = fromKeyword ? KeywordNameWeight : VectorNameWeight;
                double bw = fromKeyword ? KeywordBodyWeight : VectorBodyWeight;
                double hybrid = c.Distance - nw * nameMatch - bw * bodyMatch;
                return (Row: c, Hybrid: hybrid);
            })
            .OrderBy(x => x.Hybrid)
            .Take(topK)
            .Select(x => new ProductHit(
                x.Row.ProductId, x.Row.Sku, x.Row.Name, x.Row.CategoryName,
                x.Row.Price, x.Row.Preview, x.Hybrid))
            .ToList();

        return ranked;
    }

    /// <summary>
    /// Her token için name veya source_text içinde geçen ürünleri çeker (OR'lu LIKE).
    /// Vector pool dışı kalan tam-eşleşmeleri hybrid'e taşır.
    /// </summary>
    private async Task<List<HybridRow>> KeywordCandidatesAsync(
        IReadOnlyCollection<string> tokens, int top, CancellationToken ct)
    {
        if (tokens.Count == 0) return new();

        var i = 0;
        var paramNames = tokens.Select(_ => $"@t{i++}").ToArray();
        var orClauses = string.Join(
            " OR ",
            paramNames.Select(p => $"p.name LIKE {p} OR pe.source_text LIKE {p}"));

        var sql = $"""
            SELECT TOP (@top)
                p.product_id              AS ProductId,
                p.sku                     AS Sku,
                p.name                    AS Name,
                cat.name                  AS CategoryName,
                p.price                   AS Price,
                LEFT(p.description_tr,120) AS Preview,
                LEFT(pe.source_text, 800) AS Body,
                CAST(0.0 AS FLOAT)        AS Distance
            FROM vector.product_embedding pe
            JOIN shop.product          p   ON p.product_id   = pe.product_id
            JOIN shop.product_category cat ON cat.category_id = p.category_id
            WHERE {orClauses};
            """;

        var pars = new List<SqlParameter> { new("@top", top) };
        i = 0;
        foreach (var t in tokens) pars.Add(new SqlParameter(paramNames[i++], $"%{t}%"));

        return await db.Database.SqlQueryRaw<HybridRow>(sql, pars.ToArray()).ToListAsync(ct);
    }

    private static HashSet<string> Tokenize(string text)
    {
        if (string.IsNullOrEmpty(text)) return new HashSet<string>();
        var lower = text.ToLower(new CultureInfo("tr-TR"));
        var sb = new StringBuilder(lower.Length);
        foreach (var ch in lower)
            sb.Append(char.IsLetterOrDigit(ch) ? ch : ' ');
        return sb.ToString()
            .Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .Where(t => t.Length >= 3 && !StopWords.Contains(t))
            .ToHashSet();
    }

    // Türkçe e-ticaret sorgusu stop-word listesi.
    // "kitap"/"kitabı" listededir çünkü 50K seed'te onlarca "Tarih Kitabı / Felsefe
    // Kitabı" varyantı bulunur; bu generic terim rerank'i çarpıtır.
    private static readonly HashSet<string> StopWords = new()
    {
        "ile","için","bir","var","olan","bunu","şu","şey","veya","ama","gibi",
        "daha","çok","yine","de","da","ki","mi","mu","mü","ne","nin","nın",
        "ler","lar","istiyorum","istiyor","önerir","öner","misin","lütfen",
        "kitap","kitabı","ürün","ürünler",
        "the","and","for","with","that","this","you"
    };

    private sealed record HybridRow(
        int ProductId,
        string Sku,
        string Name,
        string CategoryName,
        decimal Price,
        string? Preview,
        string? Body,
        double Distance);

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
