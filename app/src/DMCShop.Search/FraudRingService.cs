using DMCShop.Data;
using DMCShop.Domain.Dtos;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace DMCShop.Search;

/// <summary>
/// Üç fraud pattern UNION'lanır, server-side filter + pagination ile döner.
///   1) shared_device  — aynı device birden çok customer
///   2) shared_ip      — aynı IP'yi paylaşan customer'lar
///   3) shared_card    — aynı card_fingerprint farklı müşteriler
///
/// EF Core 10'da SqlQueryRaw + CTE/OFFSET kombinasyonu "non-composable" hatası
/// veriyor; ADO.NET (Microsoft.Data.SqlClient) ile direkt komut çalıştırılır.
/// </summary>
public sealed class FraudRingService(DMCShopDbContext db)
{
    public async Task<List<FraudRing>> DetectAsync(
        int skip = 0, int take = 20,
        string? riskFilter = null,
        string? patternFilter = null,
        string? search = null,
        string sortBy = "count-desc",
        CancellationToken cancellationToken = default)
    {
        var sql = BuildSql(sortBy);
        var rows = new List<FraudRing>();

        var conn = (SqlConnection)db.Database.GetDbConnection();
        var opened = conn.State != System.Data.ConnectionState.Open;
        if (opened) await conn.OpenAsync(cancellationToken);
        try
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText    = sql;
            cmd.CommandTimeout = 60;
            cmd.Parameters.Add(new SqlParameter("@skip", skip));
            cmd.Parameters.Add(new SqlParameter("@take", take));
            cmd.Parameters.Add(new SqlParameter("@risk",    (object?)riskFilter    ?? DBNull.Value));
            cmd.Parameters.Add(new SqlParameter("@pattern", (object?)patternFilter ?? DBNull.Value));
            cmd.Parameters.Add(new SqlParameter("@search",  (object?)search        ?? DBNull.Value));

            await using var rdr = await cmd.ExecuteReaderAsync(cancellationToken);
            while (await rdr.ReadAsync(cancellationToken))
            {
                rows.Add(new FraudRing(
                    Pattern:       rdr.GetString(0),
                    RiskLevel:     rdr.GetString(1),
                    CustomerCount: rdr.GetInt32(2),
                    CustomerList:  rdr.IsDBNull(3) ? string.Empty : rdr.GetString(3),
                    Evidence:      rdr.IsDBNull(4) ? string.Empty : rdr.GetString(4)));
            }
        }
        finally
        {
            if (opened) await conn.CloseAsync();
        }
        return rows;
    }

    public async Task<FraudSummary> SummaryAsync(
        string? riskFilter = null,
        string? patternFilter = null,
        string? search = null,
        CancellationToken cancellationToken = default)
    {
        var sql = $"""
            WITH all_rings AS ({AllRingsCte()})
            SELECT
                COUNT_BIG(*)                                                AS Total,
                SUM(CASE WHEN RiskLevel = 'HIGH'   THEN 1 ELSE 0 END)        AS HighCount,
                SUM(CASE WHEN RiskLevel = 'MEDIUM' THEN 1 ELSE 0 END)        AS MediumCount,
                SUM(CASE WHEN Pattern   = 'shared_device' THEN 1 ELSE 0 END) AS DeviceCount,
                SUM(CASE WHEN Pattern   = 'shared_ip'     THEN 1 ELSE 0 END) AS IpCount,
                SUM(CASE WHEN Pattern   = 'shared_card'   THEN 1 ELSE 0 END) AS CardCount
            FROM all_rings
            WHERE (@risk    IS NULL OR RiskLevel = @risk)
              AND (@pattern IS NULL OR Pattern   = @pattern)
              AND (@search  IS NULL OR CustomerList LIKE '%' + @search + '%'
                                    OR Evidence     LIKE '%' + @search + '%');
            """;

        var conn = (SqlConnection)db.Database.GetDbConnection();
        var opened = conn.State != System.Data.ConnectionState.Open;
        if (opened) await conn.OpenAsync(cancellationToken);
        try
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText    = sql;
            cmd.CommandTimeout = 60;
            cmd.Parameters.Add(new SqlParameter("@risk",    (object?)riskFilter    ?? DBNull.Value));
            cmd.Parameters.Add(new SqlParameter("@pattern", (object?)patternFilter ?? DBNull.Value));
            cmd.Parameters.Add(new SqlParameter("@search",  (object?)search        ?? DBNull.Value));

            await using var rdr = await cmd.ExecuteReaderAsync(cancellationToken);
            await rdr.ReadAsync(cancellationToken);
            return new FraudSummary(
                Total:       rdr.GetInt64(0),
                HighCount:   rdr.IsDBNull(1) ? 0 : rdr.GetInt32(1),
                MediumCount: rdr.IsDBNull(2) ? 0 : rdr.GetInt32(2),
                DeviceCount: rdr.IsDBNull(3) ? 0 : rdr.GetInt32(3),
                IpCount:     rdr.IsDBNull(4) ? 0 : rdr.GetInt32(4),
                CardCount:   rdr.IsDBNull(5) ? 0 : rdr.GetInt32(5));
        }
        finally
        {
            if (opened) await conn.CloseAsync();
        }
    }

    private static string BuildSql(string sortBy)
    {
        var orderBy = sortBy switch
        {
            "count-asc" => "CustomerCount ASC, Pattern",
            "risk"      => "CASE RiskLevel WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END, CustomerCount DESC",
            "pattern"   => "Pattern, CustomerCount DESC",
            _           => "CustomerCount DESC, Pattern"
        };
        return $"""
            WITH all_rings AS ({AllRingsCte()})
            SELECT Pattern, RiskLevel, CustomerCount, CustomerList, Evidence
            FROM   all_rings
            WHERE (@risk    IS NULL OR RiskLevel = @risk)
              AND (@pattern IS NULL OR Pattern   = @pattern)
              AND (@search  IS NULL OR CustomerList LIKE '%' + @search + '%'
                                    OR Evidence     LIKE '%' + @search + '%')
            ORDER BY {orderBy}
            OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY;
            """;
    }

    private static string AllRingsCte() => """
        SELECT 'shared_device' AS Pattern,
               CASE WHEN cust_n >= 4 THEN 'HIGH' ELSE 'MEDIUM' END AS RiskLevel,
               cust_n AS CustomerCount,
               customers AS CustomerList,
               N'Aynı cihaz parmak izi (fp:' + ev + N'…) ' + CAST(cust_n AS NVARCHAR(8)) + N' müşteri tarafından kullanılıyor' AS Evidence
        FROM (
            SELECT d.device_id, COUNT(DISTINCT cd.customer_id) AS cust_n,
                   STRING_AGG(c.full_name, ', ') WITHIN GROUP (ORDER BY c.full_name) AS customers,
                   MAX(LEFT(d.fingerprint, 12)) AS ev
            FROM   shop.customer_device cd
            JOIN   shop.device   d ON d.device_id   = cd.device_id
            JOIN   shop.customer c ON c.customer_id = cd.customer_id
            GROUP BY d.device_id
            HAVING COUNT(DISTINCT cd.customer_id) >= 2
        ) AS sd
        UNION ALL
        SELECT 'shared_ip',
               CASE WHEN cust_n >= 5 THEN 'HIGH' ELSE 'MEDIUM' END,
               cust_n, customers,
               N'Aynı IP adresi (' + sig + N') ' + CAST(cust_n AS NVARCHAR(8)) + N' müşteri tarafından kullanılıyor'
        FROM (
            SELECT d.ip_address AS sig, COUNT(DISTINCT cd.customer_id) AS cust_n,
                   STRING_AGG(c.full_name, ', ') WITHIN GROUP (ORDER BY c.full_name) AS customers
            FROM   shop.customer_device cd
            JOIN   shop.device   d ON d.device_id   = cd.device_id
            JOIN   shop.customer c ON c.customer_id = cd.customer_id
            GROUP BY d.ip_address
            HAVING COUNT(DISTINCT cd.customer_id) >= 3
        ) AS si
        UNION ALL
        SELECT 'shared_card',
               CASE WHEN cust_n >= 3 THEN 'HIGH' ELSE 'MEDIUM' END,
               cust_n, customers,
               N'Aynı kart parmak izi (SHA-256) ' + CAST(cust_n AS NVARCHAR(8)) + N' müşteride kayıtlı'
        FROM (
            SELECT pm.card_fingerprint AS sig, COUNT(DISTINCT pm.customer_id) AS cust_n,
                   STRING_AGG(c.full_name, ', ') WITHIN GROUP (ORDER BY c.full_name) AS customers
            FROM   shop.payment_method pm
            JOIN   shop.customer       c ON c.customer_id = pm.customer_id
            WHERE  pm.card_fingerprint IS NOT NULL
            GROUP BY pm.card_fingerprint
            HAVING COUNT(DISTINCT pm.customer_id) >= 2
        ) AS sc
        """;
}

public sealed record FraudSummary(long Total, int HighCount, int MediumCount, int DeviceCount, int IpCount, int CardCount);
