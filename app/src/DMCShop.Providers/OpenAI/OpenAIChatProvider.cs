using System.Diagnostics;
using System.Runtime.CompilerServices;
using Azure;
using Azure.AI.OpenAI;
using DMCShop.Domain.Abstractions;
using Microsoft.Extensions.Options;
using OpenAI.Chat;

namespace DMCShop.Providers.OpenAI;

public sealed class OpenAIChatProvider : IChatProvider
{
    private readonly ChatClient _client;
    private readonly OpenAIOptions _options;

    public OpenAIChatProvider(IOptions<ProviderOptions> options)
    {
        _options = options.Value.OpenAI;
        var azureClient = new AzureOpenAIClient(new Uri(_options.Endpoint), new AzureKeyCredential(_options.ApiKey));
        _client = azureClient.GetChatClient(_options.ChatDeployment);
    }

    public string Name => "openai";
    public string ModelName => _options.ChatDeployment;

    public async Task<ChatResult> CompleteAsync(
        string systemPrompt,
        string userPrompt,
        IEnumerable<string> contextChunks,
        CancellationToken cancellationToken = default)
    {
        var sw = Stopwatch.StartNew();

        var context = string.Join("\n---\n", contextChunks);
        var fullPrompt = string.IsNullOrWhiteSpace(context)
            ? userPrompt
            : $"Aşağıdaki ürün listesinden faydalanarak yanıt ver:\n{context}\n\nSoru: {userPrompt}";

        var messages = new List<ChatMessage>
        {
            new SystemChatMessage(systemPrompt),
            new UserChatMessage(fullPrompt)
        };

        var response = await _client.CompleteChatAsync(messages, cancellationToken: cancellationToken);
        sw.Stop();

        var text = response.Value.Content.Count > 0 ? response.Value.Content[0].Text : string.Empty;
        return new ChatResult(text, (int)sw.ElapsedMilliseconds);
    }

    public async IAsyncEnumerable<string> StreamAsync(
        string systemPrompt,
        string userPrompt,
        IEnumerable<string> contextChunks,
        [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        var context = string.Join("\n---\n", contextChunks);
        var fullPrompt = string.IsNullOrWhiteSpace(context)
            ? userPrompt
            : $"Aşağıdaki ürün listesinden faydalanarak yanıt ver:\n{context}\n\nSoru: {userPrompt}";

        var messages = new List<ChatMessage>
        {
            new SystemChatMessage(systemPrompt),
            new UserChatMessage(fullPrompt)
        };

        await foreach (var update in _client.CompleteChatStreamingAsync(messages, cancellationToken: cancellationToken))
        {
            foreach (var part in update.ContentUpdate)
            {
                if (!string.IsNullOrEmpty(part.Text))
                    yield return part.Text;
            }
        }
    }
}
