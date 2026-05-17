using DMCShop.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DMCShop.Data.Configurations;

internal sealed class ProductEmbeddingConfiguration : IEntityTypeConfiguration<ProductEmbedding>
{
    // VECTOR(N) kolonları (embedding_openai_1536, embedding_ollama_768) EF Core 10
    // ile native eşlemez; raw SQL ile okunup yazılır. Entity yalnızca metadata
    // kolonlarını içerir.
    public void Configure(EntityTypeBuilder<ProductEmbedding> b)
    {
        b.ToTable("product_embedding", "vector");
        b.HasKey(x => x.ProductId);

        b.Property(x => x.ProductId).HasColumnName("product_id").ValueGeneratedNever();
        b.Property(x => x.SourceText).HasColumnName("source_text").IsRequired();
        b.Property(x => x.OpenaiModel).HasColumnName("openai_model").HasMaxLength(80);
        b.Property(x => x.OllamaModel).HasColumnName("ollama_model").HasMaxLength(80);
        b.Property(x => x.OpenaiUpdatedAt).HasColumnName("openai_updated_at").HasColumnType("datetime2(0)");
        b.Property(x => x.OllamaUpdatedAt).HasColumnName("ollama_updated_at").HasColumnType("datetime2(0)");

        b.Ignore("EmbeddingOpenai1536");
        b.Ignore("EmbeddingOllama768");
    }
}
