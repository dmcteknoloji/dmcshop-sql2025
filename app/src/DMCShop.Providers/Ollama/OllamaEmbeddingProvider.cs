using System.Net.Http.Json;
using System.Text.Json.Serialization;
using DMCShop.Domain.Abstractions;
using Microsoft.Extensions.Options;

namespace DMCShop.Providers.Ollama;

public sealed class OllamaEmbeddingProvider(IHttpClientFactory httpFactory, IOptions<ProviderOptions> options) : IEmbeddingProvider
{
    private readonly OllamaOptions _options = options.Value.Ollama;

    public string Name => "ollama";
    public string ModelName => _options.EmbeddingModel;
    public int Dimensions => _options.EmbeddingDimensions;

    public async Task<float[]> EmbedAsync(string text, CancellationToken cancellationToken = default)
    {
        using var http = httpFactory.CreateClient(OllamaHttpClient.Name);
        http.BaseAddress = new Uri(_options.Endpoint);

        var request = new OllamaEmbedRequest(_options.EmbeddingModel, text);
        var response = await http.PostAsJsonAsync("/api/embeddings", request, cancellationToken);
        response.EnsureSuccessStatusCode();

        var body = await response.Content.ReadFromJsonAsync<OllamaEmbedResponse>(cancellationToken)
            ?? throw new InvalidOperationException("Ollama /api/embeddings boş yanıt döndü");

        return body.Embedding;
    }

    public async Task<IReadOnlyList<float[]>> EmbedBatchAsync(IReadOnlyList<string> texts, CancellationToken cancellationToken = default)
    {
        // Ollama'nın /api/embeddings tekli endpoint; concurrency ile yönetilir.
        var results = new float[texts.Count][];
        var tasks = texts.Select(async (t, i) =>
        {
            results[i] = await EmbedAsync(t, cancellationToken);
        });
        await Task.WhenAll(tasks);
        return results;
    }
}

internal sealed record OllamaEmbedRequest(
    [property: JsonPropertyName("model")]  string Model,
    [property: JsonPropertyName("prompt")] string Prompt);

internal sealed record OllamaEmbedResponse(
    [property: JsonPropertyName("embedding")] float[] Embedding);

internal static class OllamaHttpClient
{
    public const string Name = "ollama";
}
