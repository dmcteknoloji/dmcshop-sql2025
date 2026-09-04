-- ============================================================================
-- 24-personalized.sql
-- Senaryo 5: Vector + Graph hibrit kişiselleştirilmiş öneri.
--
-- Akış:
--   1) Hedef müşterinin son N ürününün embedding'lerinden centroid (.NET'te
--      hesaplanır; T-SQL'de aggregate operatörü RTM'de yok)
--   2) VECTOR_SEARCH ile centroid'e en yakın 30 candidate
--   3) Filter: müşterinin zaten satın aldığı ürünleri çıkar
--   4) graph.purchased ile her candidate için sipariş sayısı (social proof)
--   5) Hibrit skor: distance + 1/(1+social) — küçük = daha iyi
--
-- Workshop'ta CTE pipeline halinde gösterimi için tek dosya.
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

DECLARE @customer_id INT = 10;
DECLARE @basis_limit INT = 8;
DECLARE @top_k       INT = 10;

-- ----------------------------------------------------------------------------
-- 1) Centroid — gerçek senaryoda .NET'ten gelir (string literal). Workshop
-- gösterim için: tek bir ürünün vector'ünü kullanıyoruz (degenerate centroid).
-- Üretimde: AVG_VECTOR aggregate yoksa app katmanı centroid hesaplar.
-- ----------------------------------------------------------------------------
DECLARE @centroid_json NVARCHAR(MAX);
SELECT TOP (1)
       @centroid_json = CAST(pe.embedding_bge_1024 AS NVARCHAR(MAX))
FROM   shop.[order]      o
JOIN   shop.order_line   ol ON ol.order_id   = o.order_id
JOIN   vector.product_embedding pe ON pe.product_id = ol.product_id
WHERE  o.customer_id = @customer_id
  AND  pe.embedding_bge_1024 IS NOT NULL
ORDER BY o.order_date DESC;

IF @centroid_json IS NULL
BEGIN
    PRINT N'Müşterinin embedding''li satın alma geçmişi yok.';
    RETURN;
END

DECLARE @centroid VECTOR(1024) = CAST(@centroid_json AS VECTOR(1024));

-- ----------------------------------------------------------------------------
-- 2-5) VECTOR_SEARCH + filter + graph social score + hibrit skor
-- ----------------------------------------------------------------------------
WITH hits AS (
    SELECT * FROM VECTOR_SEARCH(
        TABLE      = vector.product_embedding,
        COLUMN     = embedding_bge_1024,
        SIMILAR_TO = @centroid,
        METRIC     = 'cosine',
        TOP_N      = 30)
),
unowned AS (
    SELECT h.product_id, h.distance
    FROM   hits h
    WHERE  NOT EXISTS (
        SELECT 1
        FROM   shop.[order]    o
        JOIN   shop.order_line ol ON ol.order_id = o.order_id
        WHERE  o.customer_id = @customer_id AND ol.product_id = h.product_id
    )
),
social AS (
    SELECT
        u.product_id, u.distance,
        (SELECT COUNT(DISTINCT pur.order_id)
         FROM   graph.product_node pn,
                graph.purchased    pur,
                graph.customer_node c
         WHERE  MATCH(c-(pur)->pn)
           AND  pn.product_id = u.product_id) AS social_count
    FROM   unowned u
)
SELECT TOP (@top_k)
    s.product_id,
    p.name,
    cat.name AS category,
    p.price,
    CAST(s.distance AS DECIMAL(6, 4))                                          AS vector_distance,
    s.social_count,
    CAST(s.distance + 1.0 / (1.0 + s.social_count) AS DECIMAL(6, 4))           AS hybrid_score
FROM   social s
JOIN   shop.product          p   ON p.product_id   = s.product_id
JOIN   shop.product_category cat ON cat.category_id = p.category_id
ORDER BY hybrid_score ASC;
GO

PRINT N'> Senaryo 5: vector + graph hibrit öneriler';
GO
