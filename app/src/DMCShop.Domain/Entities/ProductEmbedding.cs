namespace DMCShop.Domain.Entities;

public sealed class ProductEmbedding
{
    public int ProductId { get; set; }
    public string SourceText { get; set; } = string.Empty;
    public string? OpenaiModel { get; set; }
    public string? OllamaModel { get; set; }
    public DateTime? OpenaiUpdatedAt { get; set; }
    public DateTime? OllamaUpdatedAt { get; set; }
}
