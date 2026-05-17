using DMCShop.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DMCShop.Data.Configurations;

internal sealed class ProductConfiguration : IEntityTypeConfiguration<Product>
{
    public void Configure(EntityTypeBuilder<Product> b)
    {
        b.ToTable("product", "shop");
        b.HasKey(x => x.ProductId);

        b.Property(x => x.ProductId).HasColumnName("product_id").ValueGeneratedNever();
        b.Property(x => x.Sku).HasColumnName("sku").HasMaxLength(32).IsRequired().IsUnicode(false);
        b.Property(x => x.Name).HasColumnName("name").HasMaxLength(200).IsRequired();
        b.Property(x => x.CategoryId).HasColumnName("category_id");
        b.Property(x => x.Price).HasColumnName("price").HasColumnType("decimal(12,2)");
        b.Property(x => x.DescriptionTr).HasColumnName("description_tr").IsRequired();
        b.Property(x => x.DescriptionEn).HasColumnName("description_en");
        b.Property(x => x.IsActive).HasColumnName("is_active");
        b.Property(x => x.CreatedAt).HasColumnName("created_at").HasColumnType("datetime2(0)");

        b.HasIndex(x => x.Sku).IsUnique();

        b.HasOne(x => x.Category)
            .WithMany(c => c.Products)
            .HasForeignKey(x => x.CategoryId);
    }
}
