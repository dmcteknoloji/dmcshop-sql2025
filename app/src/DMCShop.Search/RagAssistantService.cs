using System.Globalization;
using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;
using DMCShop.Data;
using DMCShop.Domain.Abstractions;
using DMCShop.Domain.Dtos;
using DMCShop.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace DMCShop.Search;

public sealed class RagAssistantService(
    DMCShopDbContext db,
    VectorSearchService vectorSearch,
    IChatProvider chat,
    IEmbeddingProvider embed)
{
    /// <summary>
    /// Fiyat baglamda duruyor ki model dogru urunu secebilsin, ama cevaba
    /// yazmasi yasak: 3B model numara ile adi karistirip fiyati kirpiyordu
    /// ("#1051 Kahve Demleme French Press", "920,0 ₺"). Dogru veriyi zaten
    /// sayfa "Kullanilan urunler" kartlarinda veritabanindan basiyor.
    ///
    /// Fiyati bilerek tr-TR ile bicimlendiriyoruz. Sunucunun kulturu en-US
    /// oldugu icin baglama "3,200.00" gidiyordu; model de onu oldugu gibi
    /// kopyaladigi icin Turkce cevapta Ingiliz ayraci gorunuyordu.
    /// </summary>
    /// <summary>
    /// Modelin cevabindan urun numarasi ve fiyat gibi yapilandirilmis veriyi
    /// siler.
    ///
    /// Neden kodda: prompt'ta "numara ve fiyat yazma" demek yetmedi. 3B model
    /// uc sorgunun ucunde farkli davrandi; birinde kurala uydu, ikisinde
    /// yazmaya devam etti. Once de numarayi yanlis urune baglamis
    /// ("#1051 Kahve Demleme French Press") ve fiyati kirpmisti ("920,0 ₺").
    /// Dogru veri zaten sayfadaki "Kullanilan urunler" kartlarinda,
    /// veritabanindan geliyor. Model bir cumle kursun, sayilari uygulama bassin.
    /// </summary>
    internal static string StripStructuredData(string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return text;

        var s = ProductRefPattern.Replace(text, string.Empty);   // "#1041"
        s = PricePattern.Replace(s, string.Empty);               // "1.234,56 ₺"

        // Silinen parcalarin arkasinda kalan ayraclari topla. Cumle icindeki
        // tire meşru (urun adi — kategori), yalniz basta kalan veya noktalama
        // ile bitisen tireler atiliyor.
        s = DanglingSeparator.Replace(s, string.Empty);
        s = LeadingSeparator.Replace(s, string.Empty);
        s = MultiSpace.Replace(s, " ");
        s = SpaceBeforePunctuation.Replace(s, "$1");

        return s.Trim();
    }

    private static readonly System.Text.RegularExpressions.Regex ProductRefPattern =
        new(@"#\d+\s*", System.Text.RegularExpressions.RegexOptions.Compiled);

    private static readonly System.Text.RegularExpressions.Regex PricePattern =
        new(@"\d[\d.,]*\s*₺", System.Text.RegularExpressions.RegexOptions.Compiled);

    private static readonly System.Text.RegularExpressions.Regex DanglingSeparator =
        new(@"\s*[—–-]\s*(?=[.,;:!?]|$)", System.Text.RegularExpressions.RegexOptions.Compiled);

    private static readonly System.Text.RegularExpressions.Regex LeadingSeparator =
        new(@"^\s*[—–-]\s*", System.Text.RegularExpressions.RegexOptions.Compiled);

    private static readonly System.Text.RegularExpressions.Regex MultiSpace =
        new(@"\s{2,}", System.Text.RegularExpressions.RegexOptions.Compiled);

    private static readonly System.Text.RegularExpressions.Regex SpaceBeforePunctuation =
        new(@"\s+([.,;:!?])", System.Text.RegularExpressions.RegexOptions.Compiled);

    private static readonly CultureInfo TrCulture = CultureInfo.GetCultureInfo("tr-TR");

    private const string SystemPrompt = """
        Sen DMCShop'un ürün asistanısın. Aşağıdaki davranış kuralları KESİN:

        1. SADECE sana verilen ürün listesinden faydalan. Listede olmayan ürünü asla uydurma.
        2. YANIT DİLİ: yalnızca Türkçe. İngilizce, başka dilde tek kelime veya garip
           karakter kombinasyonu (örn. selectorselam, mergeword) yazma.
        3. Yanıt kısa olsun (en fazla 3-4 cümle). Madde işareti ya da uzun açıklama yok.
        4. Ürünü ADIYLA an, bağlamda yazdığı gibi. Ürün numarası (#1041) YAZMA.
        5. Fiyat YAZMA. Fiyatı ve ürün kartını uygulama zaten ekranda gösteriyor;
           senin işin hangi ürünü neden önerdiğini bir iki cümleyle anlatmak.
        6. Soru genel ya da belirsizse bile bağlamdaki en uygun ürünü öner; listede
           birebir karşılık aramak zorunda değilsin. Yalnızca bağlam gerçekten boşsa
           "Bu sorgu için bağlamda uygun ürün bulamadım" de.
        """;

    public async Task<RagAnswer> AskAsync(string question, int topK = 5, CancellationToken cancellationToken = default)
    {
        var total = Stopwatch.StartNew();

        var rSw = Stopwatch.StartNew();
        var hits = await vectorSearch.HybridSearchAsync(question, topK, cancellationToken: cancellationToken);
        rSw.Stop();

        var contextChunks = hits.Select(h =>
            $"[#{h.ProductId}] {h.Name} — {h.CategoryName} — {h.Price.ToString("N2", TrCulture)} ₺. {h.Preview}");

        var lSw = Stopwatch.StartNew();
        var chatResult = await chat.CompleteAsync(SystemPrompt, question, contextChunks, cancellationToken);
        lSw.Stop();
        total.Stop();

        // Audit
        db.QueryLogs.Add(new QueryLog
        {
            QueryText      = question,
            Provider       = embed.Name,
            Scenario       = "rag",
            TopK           = topK,
            UsedProductIds = JsonSerializer.Serialize(hits.Select(h => h.ProductId)),
            LlmResponse    = StripStructuredData(chatResult.Text),
            LatencyMs      = (int)total.ElapsedMilliseconds,
            CreatedAt      = DateTime.UtcNow
        });
        await db.SaveChangesAsync(cancellationToken);

        return new RagAnswer(
            question,
            StripStructuredData(chatResult.Text),
            hits,
            (int)rSw.ElapsedMilliseconds,
            (int)lSw.ElapsedMilliseconds,
            (int)total.ElapsedMilliseconds);
    }

    /// <summary>
    /// Streaming RAG: önce retrieval (UsedProducts dolu, Token=""),
    /// ardından model üretirken her token chunk'ı.
    /// </summary>
    public async IAsyncEnumerable<RagStreamChunk> StreamAsync(
        string question, int topK = 5,
        [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        var total = Stopwatch.StartNew();

        var rSw = Stopwatch.StartNew();
        var hits = await vectorSearch.HybridSearchAsync(question, topK, cancellationToken: cancellationToken);
        rSw.Stop();

        // İlk chunk: retrieval bitti, henüz token yok.
        yield return new RagStreamChunk(
            UsedProducts: hits,
            TokenChunk:   string.Empty,
            RetrievalLatencyMs: (int)rSw.ElapsedMilliseconds,
            LlmLatencyMs: 0,
            TotalLatencyMs: (int)total.ElapsedMilliseconds,
            IsFinal: false);

        var contextChunks = hits.Select(h =>
            $"[#{h.ProductId}] {h.Name} — {h.CategoryName} — {h.Price.ToString("N2", TrCulture)} ₺. {h.Preview}");

        var accumulated = new StringBuilder();
        var lSw = Stopwatch.StartNew();
        await foreach (var token in chat.StreamAsync(SystemPrompt, question, contextChunks, cancellationToken))
        {
            accumulated.Append(token);
            yield return new RagStreamChunk(
                UsedProducts: hits,
                TokenChunk:   token,
                RetrievalLatencyMs: (int)rSw.ElapsedMilliseconds,
                LlmLatencyMs: (int)lSw.ElapsedMilliseconds,
                TotalLatencyMs: (int)total.ElapsedMilliseconds,
                IsFinal: false);
        }
        lSw.Stop();
        total.Stop();

        var finalText = StripStructuredData(accumulated.ToString());
        db.QueryLogs.Add(new QueryLog
        {
            QueryText      = question,
            Provider       = embed.Name,
            Scenario       = "rag-stream",
            TopK           = topK,
            UsedProductIds = JsonSerializer.Serialize(hits.Select(h => h.ProductId)),
            LlmResponse    = finalText,
            LatencyMs      = (int)total.ElapsedMilliseconds,
            CreatedAt      = DateTime.UtcNow
        });
        await db.SaveChangesAsync(cancellationToken);

        // Final marker
        yield return new RagStreamChunk(
            UsedProducts: hits,
            TokenChunk:   string.Empty,
            RetrievalLatencyMs: (int)rSw.ElapsedMilliseconds,
            LlmLatencyMs: (int)lSw.ElapsedMilliseconds,
            TotalLatencyMs: (int)total.ElapsedMilliseconds,
            IsFinal: true);
    }

    /// <summary>
    /// Geçmiş RAG kayıtları. /asistan açılışında geçmiş gösterimi için.
    /// vector.query_log'tan scenario IN ('rag','rag-stream') filtre.
    /// </summary>
    public async Task<List<RagHistoryEntry>> HistoryAsync(int limit = 10, CancellationToken cancellationToken = default)
    {
        var rows = await db.QueryLogs
            .AsNoTracking()
            .Where(q => q.Scenario == "rag" || q.Scenario == "rag-stream")
            .OrderByDescending(q => q.QueryId)
            .Take(limit)
            .Select(q => new
            {
                q.QueryId, q.CreatedAt, q.QueryText, q.LlmResponse,
                q.Provider, q.LatencyMs, q.UsedProductIds
            })
            .ToListAsync(cancellationToken);

        return rows.Select(r => new RagHistoryEntry(
            QueryId:        r.QueryId,
            CreatedAt:      r.CreatedAt,
            Question:       r.QueryText,
            Response:       r.LlmResponse ?? string.Empty,
            Provider:       r.Provider,
            LatencyMs:      r.LatencyMs ?? 0,
            UsedProductIds: ParseIdArray(r.UsedProductIds))).ToList();
    }

    private static IReadOnlyList<int> ParseIdArray(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return Array.Empty<int>();
        try { return JsonSerializer.Deserialize<int[]>(json) ?? Array.Empty<int>(); }
        catch { return Array.Empty<int>(); }
    }
}

public sealed record RagStreamChunk(
    IReadOnlyList<ProductHit> UsedProducts,
    string TokenChunk,
    int RetrievalLatencyMs,
    int LlmLatencyMs,
    int TotalLatencyMs,
    bool IsFinal);

public sealed record RagHistoryEntry(
    long QueryId,
    DateTime CreatedAt,
    string Question,
    string Response,
    string Provider,
    int LatencyMs,
    IReadOnlyList<int> UsedProductIds);
