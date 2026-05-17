namespace DMCShop.Domain.Entities;

public sealed class OrderLine
{
    public long OrderId { get; set; }
    public int ProductId { get; set; }
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }

    public Order? Order { get; set; }
    public Product? Product { get; set; }
}
