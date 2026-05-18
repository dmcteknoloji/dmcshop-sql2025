using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;
using DMCShop.Data;
using DMCShop.Domain.Abstractions;
using DMCShop.Domain.Dtos;
using DMCShop.Domain.Entities;

namespace DMCShop.Search;

public sealed class RagAssistantService(
    DMCShopDbContext db,
    VectorSearchService vectorSearch,
    IChatProvider chat,
    IEmbeddingProvider embed)
{
    private const string SystemPrompt = """
        Sen DMCShop'un ürün asistanısın. SADECE sana verilen ürün listesinden faydalanarak yanıt ver.
        Listede olmayan ürünü uydurma. Yanıtın kısa olsun (en fazla 3-4 cümle). Türkçe konuş.
        Her ürünü #ürün_no formatıyla referans ver (örn. #1041). Para birimi: ₺.
        """;

    public async Task<RagAnswer> AskAsync(string question, int topK = 5, CancellationToken cancellationToken = default)
    {
        var total = Stopwatch.StartNew();

        var rSw = Stopwatch.StartNew();
        var hits = await vectorSearch.SearchAsync(question, topK, cancellationToken);
        rSw.Stop();

        var contextChunks = hits.Select(h =>
            $"[#{h.ProductId}] {h.Name} — {h.CategoryName} — {h.Price:N2} ₺. {h.Preview}");

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
            LlmResponse    = chatResult.Text,
            LatencyMs      = (int)total.ElapsedMilliseconds,
            CreatedAt      = DateTime.UtcNow
        });
        await db.SaveChangesAsync(cancellationToken);

        return new RagAnswer(
            question,
            chatResult.Text,
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
        var hits = await vectorSearch.SearchAsync(question, topK, cancellationToken);
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
            $"[#{h.ProductId}] {h.Name} — {h.CategoryName} — {h.Price:N2} ₺. {h.Preview}");

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

        var finalText = accumulated.ToString();
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
}

public sealed record RagStreamChunk(
    IReadOnlyList<ProductHit> UsedProducts,
    string TokenChunk,
    int RetrievalLatencyMs,
    int LlmLatencyMs,
    int TotalLatencyMs,
    bool IsFinal);
