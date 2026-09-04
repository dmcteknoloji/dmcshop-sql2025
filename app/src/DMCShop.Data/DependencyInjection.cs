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

        // appsettings.json PUBLIC depoda; içinde parola tutmuyoruz. Gerçek değer
        // ortamdan gelir (scripts/sa-password.sh export eder, sunucuda
        // /etc/dmcshop/web.env taşır). Yer tutucu kaldıysa sessizce "Login failed"
        // yerine ne yapılacağını söyleyen bir hata daha yardımcı.
        if (connectionString.Contains("__DMCSHOP_SA_PASSWORD__", StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                "Bağlantı dizesindeki parola yer tutucusu doldurulmamış. " +
                "scripts/setup.sh çalıştırın ya da ConnectionStrings__DMCShop " +
                "ortam değişkenini verin (bkz. scripts/sa-password.sh).");
        }

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
