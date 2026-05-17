namespace DMCShop.Domain.Entities;

public sealed class QueryLog
{
    public long QueryId { get; set; }
    public string QueryText { get; set; } = string.Empty;
    public string Provider { get; set; } = string.Empty;
    public string Scenario { get; set; } = string.Empty;
    public int? TopK { get; set; }
    public string? UsedProductIds { get; set; }
    public string? LlmResponse { get; set; }
    public int? LatencyMs { get; set; }
    public DateTime CreatedAt { get; set; }
}
