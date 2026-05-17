using DMCShop.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DMCShop.Data.Configurations;

internal sealed class CustomerConfiguration : IEntityTypeConfiguration<Customer>
{
    public void Configure(EntityTypeBuilder<Customer> b)
    {
        b.ToTable("customer", "shop");
        b.HasKey(x => x.CustomerId);

        b.Property(x => x.CustomerId).HasColumnName("customer_id").ValueGeneratedNever();
        b.Property(x => x.FullName).HasColumnName("full_name").HasMaxLength(160).IsRequired();
        b.Property(x => x.Email).HasColumnName("email").HasMaxLength(254).IsRequired().IsUnicode(false);
        b.Property(x => x.City).HasColumnName("city").HasMaxLength(80);
        b.Property(x => x.CreatedAt).HasColumnName("created_at").HasColumnType("datetime2(0)");

        b.HasIndex(x => x.Email).IsUnique();
    }
}
