using System.Diagnostics;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using DMCShop.Domain.Abstractions;
using Microsoft.Extensions.Options;

namespace DMCShop.Providers.Ollama;

public sealed class OllamaChatProvider(IHttpClientFactory httpFactory, IOptions<ProviderOptions> options) : IChatProvider
{
    private readonly OllamaOptions _options = options.Value.Ollama;

    public string Name => "ollama";
    public string ModelName => _options.ChatModel;

    public async Task<ChatResult> CompleteAsync(
        string systemPrompt,
        string userPrompt,
        IEnumerable<string> contextChunks,
        CancellationToken cancellationToken = default)
    {
        var sw = Stopwatch.StartNew();
        using var http = httpFactory.CreateClient(OllamaHttpClient.Name);
        http.BaseAddress = new Uri(_options.Endpoint);
        http.Timeout = TimeSpan.FromSeconds(120);

        var context = string.Join("\n---\n", contextChunks);
        var fullUser = string.IsNullOrWhiteSpace(context)
            ? userPrompt
            : $"Aşağıdaki ürün listesinden faydalanarak yanıt ver:\n{context}\n\nSoru: {userPrompt}";

        var request = new OllamaChatRequest(
            _options.ChatModel,
            [
                new OllamaMessage("system", systemPrompt),
                new OllamaMessage("user",   fullUser)
            ],
            Stream: false);

        var response = await http.PostAsJsonAsync("/api/chat", request, cancellationToken);
        response.EnsureSuccessStatusCode();

        var body = await response.Content.ReadFromJsonAsync<OllamaChatResponse>(cancellationToken)
            ?? throw new InvalidOperationException("Ollama /api/chat boş yanıt döndü");

        sw.Stop();
        return new ChatResult(body.Message?.Content ?? string.Empty, (int)sw.ElapsedMilliseconds);
    }
}

internal sealed record OllamaChatRequest(
    [property: JsonPropertyName("model")]    string Model,
    [property: JsonPropertyName("messages")] IReadOnlyList<OllamaMessage> Messages,
    [property: JsonPropertyName("stream")]   bool Stream);

internal sealed record OllamaMessage(
    [property: JsonPropertyName("role")]    string Role,
    [property: JsonPropertyName("content")] string Content);

internal sealed record OllamaChatResponse(
    [property: JsonPropertyName("message")] OllamaMessage? Message);
