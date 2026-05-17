namespace DMCShop.Domain.Entities;

public sealed class PaymentMethod
{
    public long PaymentMethodId { get; set; }
    public int CustomerId { get; set; }
    public string Type { get; set; } = "card";
    public string? Last4 { get; set; }
    public string? CardFingerprint { get; set; }
    public DateTime CreatedAt { get; set; }
}
