namespace DMCShop.Domain.Entities;

public sealed class Order
{
    public long OrderId { get; set; }
    public int CustomerId { get; set; }
    public long PaymentMethodId { get; set; }
    public long? DeviceId { get; set; }
    public DateTime OrderDate { get; set; }
    public string Status { get; set; } = "pending";
    public decimal TotalAmount { get; set; }

    public Customer? Customer { get; set; }
    public ICollection<OrderLine> Lines { get; set; } = new List<OrderLine>();
}
