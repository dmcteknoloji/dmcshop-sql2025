namespace DMCShop.Domain.Dtos;

public sealed record RagAnswer(
    string                 Question,
    string                 Response,
    IReadOnlyList<ProductHit> UsedProducts,
    int                    RetrievalLatencyMs,
    int                    LlmLatencyMs,
    int                    TotalLatencyMs);
