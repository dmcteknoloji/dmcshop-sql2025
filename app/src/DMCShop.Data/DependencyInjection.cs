using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace DMCShop.Data;

public static class DependencyInjection
{
    public static IServiceCollection AddDMCShopData(this IServiceCollection services, IConfiguration config)
    {
        var connectionString = config.GetConnectionString("DMCShop")
            ?? throw new InvalidOperationException("ConnectionStrings:DMCShop tanımlı değil");

        services.AddDbContext<DMCShopDbContext>(opts =>
        {
            opts.UseSqlServer(connectionString, sql =>
            {
                sql.CommandTimeout(30);
            });
        });

        services.AddSingleton<SqlServerVersionService>();

        return services;
    }
}
