using DMCShop.Data;
using DMCShop.Domain.Dtos;
using Microsoft.EntityFrameworkCore;

namespace DMCShop.Search;

public sealed class FraudRingService(DMCShopDbContext db)
{
    /// <summary>
    /// Dört fraud pattern UNION'lanır:
    ///   1) shared_device  — aynı device birden çok customer (graph.uses_device)
    ///   2) shared_ip      — aynı IP'yi paylaşan customer'lar (uses_device → uses_ip)
    ///   3) shared_card    — aynı card_fingerprint farklı müşteriler (shop.payment_method)
    ///   4) cross_signal   — 2-hop'ta iki customer arasında bağ (SHORTEST_PATH)
    /// </summary>
    public Task<List<FraudRing>> DetectAsync(CancellationToken cancellationToken = default)
    {
        const string sql = """
            WITH shared_device AS (
                SELECT d.device_id, COUNT(DISTINCT cd.customer_id) AS cust_n,
                       STRING_AGG(c.full_name, ', ') WITHIN GROUP (ORDER BY c.full_name) AS customers,
                       MAX(LEFT(d.fingerprint, 12)) AS evidence
                FROM   shop.customer_device cd
                JOIN   shop.device   d ON d.device_id  = cd.device_id
                JOIN   shop.customer c ON c.customer_id = cd.customer_id
                GROUP BY d.device_id
                HAVING COUNT(DISTINCT cd.customer_id) >= 2
            ),
            shared_ip AS (
                SELECT d.ip_address AS sig, COUNT(DISTINCT cd.customer_id) AS cust_n,
                       STRING_AGG(c.full_name, ', ') WITHIN GROUP (ORDER BY c.full_name) AS customers
                FROM   shop.customer_device cd
                JOIN   shop.device   d ON d.device_id   = cd.device_id
                JOIN   shop.customer c ON c.customer_id = cd.customer_id
                GROUP BY d.ip_address
                HAVING COUNT(DISTINCT cd.customer_id) >= 3
            ),
            shared_card AS (
                SELECT pm.card_fingerprint AS sig, COUNT(DISTINCT pm.customer_id) AS cust_n,
                       STRING_AGG(c.full_name, ', ') WITHIN GROUP (ORDER BY c.full_name) AS customers
                FROM   shop.payment_method pm
                JOIN   shop.customer       c ON c.customer_id = pm.customer_id
                WHERE  pm.card_fingerprint IS NOT NULL
                GROUP BY pm.card_fingerprint
                HAVING COUNT(DISTINCT pm.customer_id) >= 2
            )

            SELECT 'shared_device' AS Pattern,
                   CASE WHEN cust_n >= 4 THEN 'HIGH' ELSE 'MEDIUM' END AS RiskLevel,
                   cust_n AS CustomerCount,
                   customers AS CustomerList,
                   N'Aynı cihaz parmak izi (fp:' + evidence + N'…) ' + CAST(cust_n AS NVARCHAR(8)) + N' müşteri tarafından kullanılıyor' AS Evidence
            FROM   shared_device

            UNION ALL

            SELECT 'shared_ip',
                   CASE WHEN cust_n >= 5 THEN 'HIGH' ELSE 'MEDIUM' END,
                   cust_n,
                   customers,
                   N'Aynı IP adresi (' + sig + N') ' + CAST(cust_n AS NVARCHAR(8)) + N' müşteri tarafından kullanılıyor'
            FROM   shared_ip

            UNION ALL

            SELECT 'shared_card',
                   CASE WHEN cust_n >= 3 THEN 'HIGH' ELSE 'MEDIUM' END,
                   cust_n,
                   customers,
                   N'Aynı kart parmak izi (SHA-256) ' + CAST(cust_n AS NVARCHAR(8)) + N' müşteride kayıtlı'
            FROM   shared_card

            ORDER BY CustomerCount DESC;
            """;

        return db.Database.SqlQueryRaw<FraudRing>(sql).ToListAsync(cancellationToken);
    }

    // SHORTEST_PATH ile iki müşteri arası evidence chain için sql/22-fraud-ring.sql
    // workshop dosyası içinde T-SQL örneği var. UI bu pattern'leri DetectAsync ile
    // sergiler.
}
