using DMCShop.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DMCShop.Data.Configurations;

internal sealed class OrderLineConfiguration : IEntityTypeConfiguration<OrderLine>
{
    public void Configure(EntityTypeBuilder<OrderLine> b)
    {
        b.ToTable("order_line", "shop");
        b.HasKey(x => new { x.OrderId, x.ProductId });

        b.Property(x => x.OrderId).HasColumnName("order_id");
        b.Property(x => x.ProductId).HasColumnName("product_id");
        b.Property(x => x.Quantity).HasColumnName("quantity");
        b.Property(x => x.UnitPrice).HasColumnName("unit_price").HasColumnType("decimal(12,2)");

        b.HasOne(x => x.Product)
            .WithMany()
            .HasForeignKey(x => x.ProductId);
    }
}
