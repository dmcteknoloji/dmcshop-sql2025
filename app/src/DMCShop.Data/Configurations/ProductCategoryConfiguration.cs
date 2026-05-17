using DMCShop.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DMCShop.Data.Configurations;

internal sealed class ProductCategoryConfiguration : IEntityTypeConfiguration<ProductCategory>
{
    public void Configure(EntityTypeBuilder<ProductCategory> b)
    {
        b.ToTable("product_category", "shop");
        b.HasKey(x => x.CategoryId);

        b.Property(x => x.CategoryId).HasColumnName("category_id");
        b.Property(x => x.Name).HasColumnName("name").HasMaxLength(120).IsRequired();
        b.Property(x => x.ParentCategoryId).HasColumnName("parent_category_id");
        b.Property(x => x.CreatedAt).HasColumnName("created_at").HasColumnType("datetime2(0)");

        b.HasOne(x => x.Parent)
            .WithMany()
            .HasForeignKey(x => x.ParentCategoryId);
    }
}
