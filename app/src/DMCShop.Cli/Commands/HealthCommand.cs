using DMCShop.Data;
using DMCShop.Domain.Abstractions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace DMCShop.Cli.Commands;

internal sealed class HealthCommand(IServiceProvider sp)
{
    public async Task<int> RunAsync()
    {
        using var scope = sp.CreateScope();
        var log      = scope.ServiceProvider.GetRequiredService<ILoggerFactory>().CreateLogger("health");
        var db       = scope.ServiceProvider.GetRequiredService<DMCShopDbContext>();
        var provider = scope.ServiceProvider.GetRequiredService<IEmbeddingProvider>();

        log.LogInformation("DB bağlantısı kontrol ediliyor…");
        try
        {
            var version = await db.Database.SqlQueryRaw<string>("SELECT @@VERSION AS Value").FirstAsync();
            log.LogInformation("DB OK: {Version}", version[..Math.Min(60, version.Length)]);
        }
        catch (Exception ex)
        {
            log.LogError(ex, "DB hatası");
            return 2;
        }

        log.LogInformation("Provider kontrol ediliyor: {Name}/{Model} ({Dims} dim)",
            provider.Name, provider.ModelName, provider.Dimensions);
        try
        {
            var v = await provider.EmbedAsync("merhaba dünya");
            log.LogInformation("Provider OK: ilk 5 değer = [{Sample}]",
                string.Join(", ", v.Take(5).Select(f => f.ToString("F4"))));

            if (v.Length != provider.Dimensions)
            {
                log.LogWarning("Beklenen dim {Expected}, gelen {Actual} — appsettings ile provider model uyumsuz olabilir",
                    provider.Dimensions, v.Length);
            }
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Provider hatası");
            return 3;
        }

        log.LogInformation("Tüm bileşenler sağlıklı");
        return 0;
    }
}
