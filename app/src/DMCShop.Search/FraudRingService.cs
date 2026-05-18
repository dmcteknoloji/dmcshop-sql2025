using DMCShop.Data;
using DMCShop.Domain.Dtos;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace DMCShop.Search;

public sealed class FraudRingService(DMCShopDbContext db)
{
    /// <summary>
    /// Üç fraud pattern UNION'lanır, server-side filter + pagination ile döner:
    ///   1) shared_device  — aynı device birden çok customer (graph.uses_device)
    ///   2) shared_ip      — aynı IP'yi paylaşan customer'lar (uses_device → uses_ip)
    ///   3) shared_card    — aynı card_fingerprint farklı müşteriler
    /// </summary>
    public Task<List<FraudRing>> DetectAsync(
        int skip = 0, int take = 20,
        string? riskFilter = null,
        string? patternFilter = null,
        string? search = null,
        string sortBy = "count-desc",
        CancellationToken cancellationToken = default)
    {
        var sql = BuildSql(sortBy);
        return db.Database.SqlQueryRaw<FraudRing>(sql,
            new SqlParameter("@skip", skip),
            new SqlParameter("@take", take),
            new SqlParameter("@risk",    (object?)riskFilter    ?? DBNull.Value),
            new SqlParameter("@pattern", (object?)patternFilter ?? DBNull.Value),
            new SqlParameter("@search",  (object?)search        ?? DBNull.Value)
        ).ToListAsync(cancellationToken);
    }

    public async Task<FraudSummary> SummaryAsync(
        string? riskFilter = null,
        string? patternFilter = null,
        string? search = null,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
            WITH all_rings AS (__BODY__)
            SELECT
                COUNT_BIG(*)                                                    AS Total,
                SUM(CASE WHEN RiskLevel = 'HIGH'   THEN 1 ELSE 0 END)            AS HighCount,
                SUM(CASE WHEN RiskLevel = 'MEDIUM' THEN 1 ELSE 0 END)            AS MediumCount,
                SUM(CASE WHEN Pattern   = 'shared_device' THEN 1 ELSE 0 END)    AS DeviceCount,
                SUM(CASE WHEN Pattern   = 'shared_ip'     THEN 1 ELSE 0 END)    AS IpCount,
                SUM(CASE WHEN Pattern   = 'shared_card'   THEN 1 ELSE 0 END)    AS CardCount
            FROM all_rings
            WHERE (@risk    IS NULL OR RiskLevel = @risk)
              AND (@pattern IS NULL OR Pattern   = @pattern)
              AND (@search  IS NULL OR CustomerList LIKE '%' + @search + '%'
                                    OR Evidence     LIKE '%' + @search + '%');
            """;
        var query = sql.Replace("__BODY__", AllRingsCte());
        var row = await db.Database.SqlQueryRaw<FraudSummary>(query,
            new SqlParameter("@risk",    (object?)riskFilter    ?? DBNull.Value),
            new SqlParameter("@pattern", (object?)patternFilter ?? DBNull.Value),
            new SqlParameter("@search",  (object?)search        ?? DBNull.Value)
        ).FirstAsync(cancellationToken);
        return row;
    }

    private static string BuildSql(string sortBy)
    {
        var orderBy = sortBy switch
        {
            "count-asc"   => "CustomerCount ASC, Pattern",
            "risk"        => "CASE RiskLevel WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END, CustomerCount DESC",
            "pattern"     => "Pattern, CustomerCount DESC",
            _             => "CustomerCount DESC, Pattern"
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
