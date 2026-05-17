using Azure;
using Azure.AI.OpenAI;
using DMCShop.Domain.Abstractions;
using Microsoft.Extensions.Options;
using OpenAI.Embeddings;

namespace DMCShop.Providers.OpenAI;

public sealed class OpenAIEmbeddingProvider : IEmbeddingProvider
{
    private readonly EmbeddingClient _client;
    private readonly OpenAIOptions _options;

    public OpenAIEmbeddingProvider(IOptions<ProviderOptions> options)
    {
        _options = options.Value.OpenAI;
        if (string.IsNullOrWhiteSpace(_options.Endpoint))
            throw new InvalidOperationException("Provider:OpenAI:Endpoint tanımlı değil");
        if (string.IsNullOrWhiteSpace(_options.ApiKey))
            throw new InvalidOperationException("Provider:OpenAI:ApiKey tanımlı değil");

        var azureClient = new AzureOpenAIClient(new Uri(_options.Endpoint), new AzureKeyCredential(_options.ApiKey));
        _client = azureClient.GetEmbeddingClient(_options.EmbeddingDeployment);
    }

    public string Name => "openai";
    public string ModelName => _options.EmbeddingDeployment;
    public int Dimensions => _options.EmbeddingDimensions;

    public async Task<float[]> EmbedAsync(string text, CancellationToken cancellationToken = default)
    {
        var result = await _client.GenerateEmbeddingAsync(text, cancellationToken: cancellationToken);
        return result.Value.ToFloats().ToArray();
    }

    public async Task<IReadOnlyList<float[]>> EmbedBatchAsync(IReadOnlyList<string> texts, CancellationToken cancellationToken = default)
    {
        if (texts.Count == 0) return [];

        var result = await _client.GenerateEmbeddingsAsync(texts, cancellationToken: cancellationToken);
        return [.. result.Value.Select(e => e.ToFloats().ToArray())];
    }
}
