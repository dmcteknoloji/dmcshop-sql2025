namespace DMCShop.Domain.Abstractions;

public interface IEmbeddingProvider
{
    string Name { get; }
    string ModelName { get; }
    int Dimensions { get; }

    Task<float[]> EmbedAsync(string text, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<float[]>> EmbedBatchAsync(IReadOnlyList<string> texts, CancellationToken cancellationToken = default);
}
