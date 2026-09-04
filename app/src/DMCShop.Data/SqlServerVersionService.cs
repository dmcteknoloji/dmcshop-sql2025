using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace DMCShop.Data;

/// <summary>
/// Arayuzdeki surum rozetini calisma aninda sunucudan okur.
/// Rozet daha once koda gomuluydu ("RTM-CU4") ve compose etiketi
/// 2025-latest oldugu icin her dagitimda sessizce bayatliyordu:
/// sunucu CU8'e cikmisti, ekranda hala CU4 yaziyordu.
/// </summary>
public sealed class SqlServerVersionService(IServiceScopeFactory scopeFactory)
{
    public const string Fallback = "SQL Server 2025";

    private readonly SemaphoreSlim gate = new(1, 1);
    private string? cached;

    public async Task<string> GetLabelAsync(CancellationToken ct = default)
    {
        if (cached is not null) return cached;

        await gate.WaitAsync(ct);
        try
        {
            if (cached is not null) return cached;
            cached = await ReadAsync(ct);
            return cached;
        }
        finally
        {
            gate.Release();
        }
    }

    private async Task<string> ReadAsync(CancellationToken ct)
    {
        try
        {
            using var scope = scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<DMCShopDbContext>();

            var conn = db.Database.GetDbConnection();
            if (conn.State != System.Data.ConnectionState.Open)
                await conn.OpenAsync(ct);

            using var cmd = conn.CreateCommand();
            cmd.CommandText = """
                SELECT CONVERT(varchar(20), SERVERPROPERTY(N'ProductMajorVersion')),
                       CONVERT(varchar(40), SERVERPROPERTY(N'ProductLevel')),
                       CONVERT(varchar(40), SERVERPROPERTY(N'ProductUpdateLevel'))
                """;

            using var reader = await cmd.ExecuteReaderAsync(ct);
            if (!await reader.ReadAsync(ct)) return Fallback;

            var major = reader.IsDBNull(0) ? null : reader.GetString(0);
            var level = reader.IsDBNull(1) ? null : reader.GetString(1);
            var update = reader.IsDBNull(2) ? null : reader.GetString(2);

            return Compose(major, level, update);
        }
        catch
        {
            // Rozet yuzunden sayfa patlamasin; veritabani yoksa da site acilir.
            return Fallback;
        }
    }

    internal static string Compose(string? major, string? level, string? update)
    {
        var product = major switch
        {
            "17" => "SQL Server 2025",
            "16" => "SQL Server 2022",
            "15" => "SQL Server 2019",
            _ => "SQL Server",
        };

        // ProductUpdateLevel yalnizca bir CU kuruluysa dolu gelir.
        var suffix = (level, update) switch
        {
            (null or "", null or "") => null,
            (var l, null or "") => l,
            (null or "", var u) => u,
            var (l, u) => $"{l}-{u}",
        };

        return suffix is null ? product : $"{product} {suffix}";
    }
}
