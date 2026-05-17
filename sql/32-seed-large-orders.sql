-- ============================================================================
-- 32-seed-large-orders.sql
-- 100.000 sipariş + ~350.000 sipariş satırı + 4000 ek device + 50+ fraud ring.
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

-- ----------------------------------------------------------------------------
-- 4.000 ek device (id 300..4299) + fraud ring injection
-- ----------------------------------------------------------------------------

WITH numbers AS (
    SELECT TOP (4000) 300 + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS device_id
    FROM sys.all_objects o1 CROSS JOIN sys.all_objects o2
)
INSERT INTO shop.device (device_id, fingerprint, ip_address, user_agent, first_seen, last_seen)
SELECT
    n.device_id,
    CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CAST(n.device_id AS VARCHAR(20))), 2),
    -- Fraud ring injection: device_id 300-399 her 10'lu grup aynı IP'yi paylaşır
    CASE WHEN n.device_id BETWEEN 300 AND 399
         THEN '198.51.100.' + CAST(((n.device_id - 300) / 10) + 1 AS VARCHAR(3))
         ELSE '203.0.113.'  + CAST(((n.device_id * 7) % 254) + 1 AS VARCHAR(3))
    END,
    CASE (n.device_id % 4)
        WHEN 0 THEN 'Mozilla/5.0 (Windows NT 10.0) Chrome/130'
        WHEN 1 THEN 'Mozilla/5.0 (Macintosh) Safari/17'
        WHEN 2 THEN 'Mozilla/5.0 (iPhone) Mobile Safari'
        ELSE        'Mozilla/5.0 (Android 14) Chrome'
    END,
    DATEADD(MINUTE, (n.device_id * 13) % (365 * 24 * 60), '2026-01-01'),
    DATEADD(MINUTE, (n.device_id * 13) % (365 * 24 * 60) + 60 * 24 * 30, '2026-01-01')
FROM numbers n;

PRINT '> 4.000 ek device eklendi (300..4299)';

-- customer_device — her yeni müşteriye 1 device atama (mod ile balance)
INSERT INTO shop.customer_device (customer_id, device_id, first_seen, last_seen)
SELECT
    c.customer_id,
    300 + ((c.customer_id - 50) % 4000) AS device_id,
    c.created_at,
    DATEADD(DAY, 90, c.created_at)
FROM shop.customer c
WHERE c.customer_id > 50;

PRINT '> 10.000 ek customer_device eklendi';

-- ----------------------------------------------------------------------------
-- 100.000 sipariş — her müşteriye ortalama 10 sipariş; tarih dağılımı:
-- 2026-01 → 2026-04 (4 aya yayılmış)
-- ----------------------------------------------------------------------------

WITH numbers AS (
    SELECT TOP (100000) 10400 + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS order_id
    FROM sys.all_objects o1 CROSS JOIN sys.all_objects o2 CROSS JOIN sys.all_objects o3
)
INSERT INTO shop.[order] (order_id, customer_id, payment_method_id, device_id, order_date, status, total_amount)
SELECT
    n.order_id,
    -- Müşteri dağılımı: 1..10050; eski 50 müşteri %5 ağırlık, yeni 10000 müşteri %95
    50 + ((n.order_id * 7) % 10000) + 1 AS customer_id,
    -- payment_method: müşterinin ilk payment_method (genelde customer_id + 50 = pmid)
    50 + ((n.order_id * 7) % 10000) + 1 AS payment_method_id,
    -- device: customer'ın bilinen device'larından biri
    300 + (((n.order_id * 7) % 10000) % 4000) AS device_id,
    DATEADD(MINUTE, (n.order_id * 17) % (4 * 30 * 24 * 60), '2026-01-01') AS order_date,
    'paid' AS status,
    0 AS total_amount
FROM numbers n;

PRINT '> 100.000 sipariş eklendi';

-- ----------------------------------------------------------------------------
-- ~350.000 sipariş satırı — her sipariş için ortalama 3.5 ürün
-- ----------------------------------------------------------------------------

-- Sayım tablosu (1..7 arası satır sayısı)
WITH line_count AS (
    SELECT order_id, ((order_id * 13) % 6) + 2 AS lc  -- 2..7 satır
    FROM shop.[order]
    WHERE order_id > 10400
),
expanded AS (
    SELECT lc.order_id, n.idx
    FROM line_count lc
    JOIN (VALUES (1),(2),(3),(4),(5),(6),(7)) AS n(idx) ON n.idx <= lc.lc
)
INSERT INTO shop.order_line (order_id, product_id, quantity, unit_price)
SELECT
    e.order_id,
    p.product_id,
    1 + ((e.order_id + e.idx) % 3) AS quantity,
    p.price AS unit_price
FROM expanded e
CROSS APPLY (
    SELECT TOP 1 product_id, price
    FROM shop.product
    WHERE product_id >= 1001 + ((e.order_id * 11 + e.idx * 19) % 50000)
    ORDER BY product_id
) p
WHERE NOT EXISTS (
    SELECT 1 FROM shop.order_line ol
    WHERE ol.order_id = e.order_id AND ol.product_id = p.product_id
);

PRINT '> Sipariş satırları eklendi';

-- Sipariş toplamlarını güncelle
UPDATE o
SET    total_amount = COALESCE((SELECT SUM(ol.quantity * ol.unit_price)
                                FROM shop.order_line ol
                                WHERE ol.order_id = o.order_id), 0)
FROM   shop.[order] o
WHERE  o.order_id > 10400;

PRINT '> Sipariş total_amount güncellendi';

-- Doğrulama
SELECT 'order (total)' AS entity, COUNT(*) AS n FROM shop.[order]
UNION ALL SELECT 'order_line (total)', COUNT(*) FROM shop.order_line
UNION ALL SELECT 'device (total)',     COUNT(*) FROM shop.device
UNION ALL SELECT 'customer_device',    COUNT(*) FROM shop.customer_device;
GO
