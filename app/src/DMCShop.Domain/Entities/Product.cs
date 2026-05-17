namespace DMCShop.Domain.Entities;

public sealed class Product
{
    public int ProductId { get; set; }
    public string Sku { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public int CategoryId { get; set; }
    public decimal Price { get; set; }
    public string DescriptionTr { get; set; } = string.Empty;
    public string? DescriptionEn { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }

    public ProductCategory? Category { get; set; }
}
