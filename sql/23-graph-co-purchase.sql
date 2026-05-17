-- ============================================================================
-- 23-graph-co-purchase.sql
-- Senaryo 4: "Bunu alanlar bunu da aldı" — graph MATCH 2-hop traversal.
-- p1 <- (purchased) - customer - (purchased) -> p2 zinciri, p1 verili,
-- p2'leri birlikte alınma sıklığına göre sırala.
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

-- ----------------------------------------------------------------------------
-- (a) Belirli bir ürün için co-purchase önerileri (2-hop pattern)
-- Örnek: ürün 1041 (Etiyopya Kahve Çekirdeği) — bunu alan müşterilerin
-- birlikte aldığı diğer ürünleri sırala.
-- ----------------------------------------------------------------------------
DECLARE @seed_product_id INT = 1041;

SELECT TOP (10)
    p2.product_id   AS recommended_product_id,
    p2.name         AS recommended_name,
    p2_cat.name     AS category,
    p2.price,
    COUNT(DISTINCT c.customer_id) AS co_buyer_count
FROM graph.product_node   p1,
     graph.purchased      pur1,
     graph.customer_node  c,
     graph.purchased      pur2,
     graph.product_node   p2,
     shop.product         p2_shop,
     shop.product_category p2_cat
WHERE MATCH(p1<-(pur1)-c-(pur2)->p2)
  AND p1.product_id = @seed_product_id
  AND p2.product_id <> @seed_product_id
  AND p2_shop.product_id = p2.product_id
  AND p2_cat.category_id = p2_shop.category_id
GROUP BY
    p2.product_id, p2.display_name, p2_shop.name, p2_shop.price,
    p2.name, p2_cat.name
ORDER BY co_buyer_count DESC;
GO

-- ----------------------------------------------------------------------------
-- (b) Tüm ürün çiftlerinin co-purchase matrisi (üst 20)
-- Workshop için ek demo: "hangi iki ürün en çok birlikte alınıyor?"
-- ----------------------------------------------------------------------------
SELECT TOP (20)
    LEAST   (p1.product_id, p2.product_id) AS product_a,
    GREATEST(p1.product_id, p2.product_id) AS product_b,
    pa.name AS name_a,
    pb.name AS name_b,
    COUNT(DISTINCT c.customer_id) AS co_buyer_count
FROM graph.product_node   p1,
     graph.purchased      pur1,
     graph.customer_node  c,
     graph.purchased      pur2,
     graph.product_node   p2,
     shop.product         pa,
     shop.product         pb
WHERE MATCH(p1<-(pur1)-c-(pur2)->p2)
  AND p1.product_id < p2.product_id
  AND pa.product_id = p1.product_id
  AND pb.product_id = p2.product_id
GROUP BY p1.product_id, p2.product_id, pa.name, pb.name
ORDER BY co_buyer_count DESC;
GO

-- ----------------------------------------------------------------------------
-- (c) Relational karşılaştırma — aynı sonuç JOIN/EXISTS ile.
-- Graph MATCH'in semantic okunabilirliğini hissetmek için.
-- ----------------------------------------------------------------------------
/*
DECLARE @seed INT = 1041;

SELECT TOP (10)
    p2.product_id, p2.name, COUNT(DISTINCT o1.customer_id) AS co_buyer_count
FROM shop.order_line ol1
JOIN shop.[order]    o1 ON o1.order_id = ol1.order_id
JOIN shop.[order]    o2 ON o2.customer_id = o1.customer_id
JOIN shop.order_line ol2 ON ol2.order_id = o2.order_id
JOIN shop.product    p2  ON p2.product_id = ol2.product_id
WHERE ol1.product_id = @seed
  AND ol2.product_id <> @seed
GROUP BY p2.product_id, p2.name
ORDER BY co_buyer_count DESC;
*/
GO
