using DMCShop.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DMCShop.Data.Configurations;

internal sealed class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> b)
    {
        b.ToTable("order", "shop");   // SQL Server provider [order] olarak quote eder
        b.HasKey(x => x.OrderId);

        b.Property(x => x.OrderId).HasColumnName("order_id").ValueGeneratedNever();
        b.Property(x => x.CustomerId).HasColumnName("customer_id");
        b.Property(x => x.PaymentMethodId).HasColumnName("payment_method_id");
        b.Property(x => x.DeviceId).HasColumnName("device_id");
        b.Property(x => x.OrderDate).HasColumnName("order_date").HasColumnType("datetime2(0)");
        b.Property(x => x.Status).HasColumnName("status").HasMaxLength(20).IsRequired().IsUnicode(false);
        b.Property(x => x.TotalAmount).HasColumnName("total_amount").HasColumnType("decimal(14,2)");

        b.HasOne(x => x.Customer)
            .WithMany()
            .HasForeignKey(x => x.CustomerId);

        b.HasMany(x => x.Lines)
            .WithOne(l => l.Order)
            .HasForeignKey(l => l.OrderId);
    }
}
