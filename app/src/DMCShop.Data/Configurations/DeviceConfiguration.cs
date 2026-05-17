using DMCShop.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DMCShop.Data.Configurations;

internal sealed class DeviceConfiguration : IEntityTypeConfiguration<Device>
{
    public void Configure(EntityTypeBuilder<Device> b)
    {
        b.ToTable("device", "shop");
        b.HasKey(x => x.DeviceId);

        b.Property(x => x.DeviceId).HasColumnName("device_id").ValueGeneratedNever();
        b.Property(x => x.Fingerprint).HasColumnName("fingerprint").HasMaxLength(64).IsFixedLength().IsUnicode(false);
        b.Property(x => x.IpAddress).HasColumnName("ip_address").HasMaxLength(45);
        b.Property(x => x.UserAgent).HasColumnName("user_agent").HasMaxLength(400);
        b.Property(x => x.FirstSeen).HasColumnName("first_seen").HasColumnType("datetime2(0)");
        b.Property(x => x.LastSeen).HasColumnName("last_seen").HasColumnType("datetime2(0)");
    }
}
