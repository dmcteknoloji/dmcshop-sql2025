namespace DMCShop.Domain.Abstractions;

public interface IChatProvider
{
    string Name { get; }
    string ModelName { get; }

    Task<ChatResult> CompleteAsync(
        string systemPrompt,
        string userPrompt,
        IEnumerable<string> contextChunks,
        CancellationToken cancellationToken = default);
}

public sealed record ChatResult(string Text, int LatencyMs);
