using System.Diagnostics;
using System.Net.Http.Json;
using System.Runtime.CompilerServices;
using System.Text.Json;
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
            Stream: false,
            Options: new OllamaChatOptions());

        var response = await http.PostAsJsonAsync("/api/chat", request, cancellationToken);
        response.EnsureSuccessStatusCode();

        var body = await response.Content.ReadFromJsonAsync<OllamaChatResponse>(cancellationToken)
            ?? throw new InvalidOperationException("Ollama /api/chat boş yanıt döndü");

        sw.Stop();
        return new ChatResult(body.Message?.Content ?? string.Empty, (int)sw.ElapsedMilliseconds);
    }

    public async IAsyncEnumerable<string> StreamAsync(
        string systemPrompt,
        string userPrompt,
        IEnumerable<string> contextChunks,
        [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        var http = httpFactory.CreateClient(OllamaHttpClient.Name);
        http.BaseAddress = new Uri(_options.Endpoint);
        http.Timeout = TimeSpan.FromMinutes(5);

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
            Stream: true,
            Options: new OllamaChatOptions(NumPredict: 200));

        using var content = JsonContent.Create(request);
        using var req = new HttpRequestMessage(HttpMethod.Post, "/api/chat") { Content = content };
        using var resp = await http.SendAsync(req, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        resp.EnsureSuccessStatusCode();

        await using var stream = await resp.Content.ReadAsStreamAsync(cancellationToken);
        using var reader = new StreamReader(stream);

        while (true)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var line = await reader.ReadLineAsync(cancellationToken);
            if (line is null) break;
            if (string.IsNullOrWhiteSpace(line)) continue;

            using var doc = JsonDocument.Parse(line);
            if (doc.RootElement.TryGetProperty("message", out var msg) &&
                msg.TryGetProperty("content", out var ct) &&
                ct.GetString() is { Length: > 0 } chunk)
            {
                yield return chunk;
            }
            if (doc.RootElement.TryGetProperty("done", out var done) && done.GetBoolean()) break;
        }
    }
}

internal sealed record OllamaChatRequest(
    [property: JsonPropertyName("model")]    string Model,
    [property: JsonPropertyName("messages")] IReadOnlyList<OllamaMessage> Messages,
    [property: JsonPropertyName("stream")]   bool Stream,
    [property: JsonPropertyName("options")]  OllamaChatOptions? Options = null);

// num_predict: yanıt token tavanı. CPU-only B4ms'te tek token ~50-80 ms;
// 160 token üst sınır ortalama yanıtı ~10-13 sn'ye çeker. System prompt
// zaten "3-4 cümle" kısıtı koyduğu için kesim çok nadir görülür.
internal sealed record OllamaChatOptions(
    [property: JsonPropertyName("num_predict")] int NumPredict = 160,
    [property: JsonPropertyName("temperature")] double Temperature = 0.2);

internal sealed record OllamaMessage(
    [property: JsonPropertyName("role")]    string Role,
    [property: JsonPropertyName("content")] string Content);

internal sealed record OllamaChatResponse(
    [property: JsonPropertyName("message")] OllamaMessage? Message);
