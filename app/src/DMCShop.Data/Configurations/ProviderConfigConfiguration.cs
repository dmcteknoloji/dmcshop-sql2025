using DMCShop.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DMCShop.Data.Configurations;

internal sealed class ProviderConfigConfiguration : IEntityTypeConfiguration<ProviderConfig>
{
    public void Configure(EntityTypeBuilder<ProviderConfig> b)
    {
        b.ToTable("provider_config", "ops");
        b.HasKey(x => x.ConfigKey);

        b.Property(x => x.ConfigKey).HasColumnName("config_key").HasMaxLength(40).IsUnicode(false);
        b.Property(x => x.Provider).HasColumnName("provider").HasMaxLength(20).IsUnicode(false);
        b.Property(x => x.ModelName).HasColumnName("model_name").HasMaxLength(120);
        b.Property(x => x.EndpointUrl).HasColumnName("endpoint_url").HasMaxLength(400);
        b.Property(x => x.CredentialName).HasColumnName("credential_name").HasMaxLength(200);
        b.Property(x => x.IsActive).HasColumnName("is_active");
        b.Property(x => x.UpdatedAt).HasColumnName("updated_at").HasColumnType("datetime2(0)");
    }
}
