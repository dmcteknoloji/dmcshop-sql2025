using DMCShop.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DMCShop.Data.Configurations;

internal sealed class QueryLogConfiguration : IEntityTypeConfiguration<QueryLog>
{
    public void Configure(EntityTypeBuilder<QueryLog> b)
    {
        b.ToTable("query_log", "vector");
        b.HasKey(x => x.QueryId);

        b.Property(x => x.QueryId).HasColumnName("query_id").ValueGeneratedOnAdd();
        b.Property(x => x.QueryText).HasColumnName("query_text").IsRequired();
        b.Property(x => x.Provider).HasColumnName("provider").HasMaxLength(20).IsRequired().IsUnicode(false);
        b.Property(x => x.Scenario).HasColumnName("scenario").HasMaxLength(40).IsRequired().IsUnicode(false);
        b.Property(x => x.TopK).HasColumnName("top_k");
        b.Property(x => x.UsedProductIds).HasColumnName("used_product_ids");
        b.Property(x => x.LlmResponse).HasColumnName("llm_response");
        b.Property(x => x.LatencyMs).HasColumnName("latency_ms");
        b.Property(x => x.CreatedAt).HasColumnName("created_at").HasColumnType("datetime2(0)");
    }
}
