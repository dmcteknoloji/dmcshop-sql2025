namespace DMCShop.Providers;

public sealed class ProviderOptions
{
    public const string SectionName = "Provider";

    /// <summary>"openai" veya "ollama"</summary>
    public string Active { get; set; } = "ollama";

    public OpenAIOptions OpenAI { get; set; } = new();
    public OllamaOptions Ollama { get; set; } = new();
}

public sealed class OpenAIOptions
{
    public string Endpoint { get; set; } = string.Empty;
    public string ApiKey { get; set; } = string.Empty;
    public string EmbeddingDeployment { get; set; } = "text-embedding-3-small";
    public string ChatDeployment { get; set; } = "gpt-4o-mini";
    public int EmbeddingDimensions { get; set; } = 1536;
}

public sealed class OllamaOptions
{
    public string Endpoint { get; set; } = "http://localhost:11434";
    public string EmbeddingModel { get; set; } = "nomic-embed-text";
    public string ChatModel { get; set; } = "llama3.1:8b-instruct";
    public int EmbeddingDimensions { get; set; } = 768;
}
