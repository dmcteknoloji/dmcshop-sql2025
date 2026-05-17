using DMCShop.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DMCShop.Data.Configurations;

internal sealed class PaymentMethodConfiguration : IEntityTypeConfiguration<PaymentMethod>
{
    public void Configure(EntityTypeBuilder<PaymentMethod> b)
    {
        b.ToTable("payment_method", "shop");
        b.HasKey(x => x.PaymentMethodId);

        b.Property(x => x.PaymentMethodId).HasColumnName("payment_method_id").ValueGeneratedNever();
        b.Property(x => x.CustomerId).HasColumnName("customer_id");
        b.Property(x => x.Type).HasColumnName("type").HasMaxLength(20).IsRequired().IsUnicode(false);
        b.Property(x => x.Last4).HasColumnName("last4").HasMaxLength(4).IsFixedLength().IsUnicode(false);
        b.Property(x => x.CardFingerprint).HasColumnName("card_fingerprint").HasMaxLength(64).IsFixedLength().IsUnicode(false);
        b.Property(x => x.CreatedAt).HasColumnName("created_at").HasColumnType("datetime2(0)");
    }
}
