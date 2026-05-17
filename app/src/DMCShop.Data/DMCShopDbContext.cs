using DMCShop.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace DMCShop.Data;

public sealed class DMCShopDbContext(DbContextOptions<DMCShopDbContext> options) : DbContext(options)
{
    public DbSet<ProductCategory> ProductCategories => Set<ProductCategory>();
    public DbSet<Product> Products => Set<Product>();
    public DbSet<Customer> Customers => Set<Customer>();
    public DbSet<PaymentMethod> PaymentMethods => Set<PaymentMethod>();
    public DbSet<Device> Devices => Set<Device>();
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<OrderLine> OrderLines => Set<OrderLine>();
    public DbSet<ProductEmbedding> ProductEmbeddings => Set<ProductEmbedding>();
    public DbSet<ProviderConfig> ProviderConfigs => Set<ProviderConfig>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(DMCShopDbContext).Assembly);
    }
}
