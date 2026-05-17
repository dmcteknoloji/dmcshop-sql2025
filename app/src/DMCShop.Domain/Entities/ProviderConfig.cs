namespace DMCShop.Domain.Entities;

public sealed class ProviderConfig
{
    public string ConfigKey { get; set; } = string.Empty;
    public string Provider { get; set; } = string.Empty;
    public string ModelName { get; set; } = string.Empty;
    public string EndpointUrl { get; set; } = string.Empty;
    public string? CredentialName { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime UpdatedAt { get; set; }
}
