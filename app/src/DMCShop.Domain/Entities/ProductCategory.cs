namespace DMCShop.Domain.Entities;

public sealed class ProductCategory
{
    public int CategoryId { get; set; }
    public string Name { get; set; } = string.Empty;
    public int? ParentCategoryId { get; set; }
    public DateTime CreatedAt { get; set; }

    public ProductCategory? Parent { get; set; }
    public ICollection<Product> Products { get; set; } = new List<Product>();
}
