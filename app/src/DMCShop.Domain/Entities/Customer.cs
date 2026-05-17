namespace DMCShop.Domain.Entities;

public sealed class Customer
{
    public int CustomerId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? City { get; set; }
    public DateTime CreatedAt { get; set; }
}
