using DMCShop.Data;
using DMCShop.Domain.Dtos;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace DMCShop.Search;

public sealed class GraphRecommendService(DMCShopDbContext db)
{
    /// <summary>
    /// "Bunu alanlar bunu da aldı" — 2-hop graph MATCH:
    /// p1 &lt;- (purchased) - customer - (purchased) -&gt; p2
    /// </summary>
    public Task<List<CoPurchaseRow>> CoPurchaseAsync(int seedProductId, int topK = 10, CancellationToken cancellationToken = default)
    {
        const string sql = """
            SELECT TOP (@topK)
                p2.product_id                  AS RecommendedProductId,
                p2_shop.name                   AS RecommendedName,
                p2_cat.name                    AS CategoryName,
                p2_shop.price                  AS Price,
                COUNT(DISTINCT c.customer_id)  AS CoBuyerCount
            FROM graph.product_node    p1,
                 graph.purchased       pur1,
                 graph.customer_node   c,
                 graph.purchased       pur2,
                 graph.product_node    p2,
                 shop.product          p2_shop,
                 shop.product_category p2_cat
            WHERE MATCH(p1<-(pur1)-c-(pur2)->p2)
              AND p1.product_id = @seed
              AND p2.product_id <> @seed
              AND p2_shop.product_id = p2.product_id
              AND p2_cat.category_id = p2_shop.category_id
            GROUP BY p2.product_id, p2_shop.name, p2_cat.name, p2_shop.price
            ORDER BY CoBuyerCount DESC;
            """;

        return db.Database
            .SqlQueryRaw<CoPurchaseRow>(sql,
                new SqlParameter("@seed", seedProductId),
                new SqlParameter("@topK", topK))
            .ToListAsync(cancellationToken);
    }
}
