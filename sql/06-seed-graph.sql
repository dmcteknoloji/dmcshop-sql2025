-- ============================================================================
-- 06-seed-graph.sql
-- graph.* tablolarına shop.* verisinden synthesize ile veri yükle.
-- Önkoşul: 05-seed-shop.sql tamamlandı.
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

-- ----------------------------------------------------------------------------
-- NODE tabloları
-- ----------------------------------------------------------------------------

INSERT INTO graph.customer_node (customer_id, display_name)
SELECT customer_id, full_name FROM shop.customer;

INSERT INTO graph.product_node (product_id, display_name)
SELECT product_id, name FROM shop.product;

INSERT INTO graph.device_node (device_id, fingerprint_short)
SELECT device_id, LEFT(fingerprint, 12) FROM shop.device;

INSERT INTO graph.payment_node (payment_method_id, last4_masked)
SELECT payment_method_id, '**' + last4 FROM shop.payment_method WHERE last4 IS NOT NULL;

INSERT INTO graph.ip_node (ip_address)
SELECT DISTINCT ip_address FROM shop.device;

PRINT '> NODE''lar dolduruldu';

-- ----------------------------------------------------------------------------
-- EDGE tabloları
-- ----------------------------------------------------------------------------

-- purchased: customer → product (her order_line bir edge)
INSERT INTO graph.purchased ($from_id, $to_id, order_id, quantity, ts)
SELECT
    cn.$node_id,
    pn.$node_id,
    ol.order_id,
    ol.quantity,
    o.order_date
FROM shop.order_line ol
JOIN shop.[order]         o  ON o.order_id      = ol.order_id
JOIN graph.customer_node  cn ON cn.customer_id  = o.customer_id
JOIN graph.product_node   pn ON pn.product_id   = ol.product_id;

-- viewed: customer → product
INSERT INTO graph.viewed ($from_id, $to_id, ts)
SELECT
    cn.$node_id,
    pn.$node_id,
    pv.viewed_at
FROM shop.product_view    pv
JOIN graph.customer_node  cn ON cn.customer_id  = pv.customer_id
JOIN graph.product_node   pn ON pn.product_id   = pv.product_id;

-- uses_device: customer → device
INSERT INTO graph.uses_device ($from_id, $to_id, first_seen, last_seen)
SELECT
    cn.$node_id,
    dn.$node_id,
    cd.first_seen,
    cd.last_seen
FROM shop.customer_device cd
JOIN graph.customer_node  cn ON cn.customer_id = cd.customer_id
JOIN graph.device_node    dn ON dn.device_id   = cd.device_id;

-- uses_ip: device → ip (her device kendi IP'sine bağlanır)
INSERT INTO graph.uses_ip ($from_id, $to_id, ts)
SELECT
    dn.$node_id,
    ipn.$node_id,
    d.first_seen
FROM shop.device          d
JOIN graph.device_node    dn  ON dn.device_id  = d.device_id
JOIN graph.ip_node        ipn ON ipn.ip_address = d.ip_address;

-- pays_with: customer → payment_method
INSERT INTO graph.pays_with ($from_id, $to_id, ts)
SELECT
    cn.$node_id,
    payn.$node_id,
    pm.created_at
FROM shop.payment_method  pm
JOIN graph.customer_node  cn   ON cn.customer_id        = pm.customer_id
JOIN graph.payment_node   payn ON payn.payment_method_id = pm.payment_method_id;

PRINT '> EDGE''ler dolduruldu';
GO

-- Doğrulama
SELECT 'customer_node' AS entity, COUNT(*) AS n FROM graph.customer_node
UNION ALL SELECT 'product_node',    COUNT(*) FROM graph.product_node
UNION ALL SELECT 'device_node',     COUNT(*) FROM graph.device_node
UNION ALL SELECT 'payment_node',    COUNT(*) FROM graph.payment_node
UNION ALL SELECT 'ip_node',         COUNT(*) FROM graph.ip_node
UNION ALL SELECT 'purchased',       COUNT(*) FROM graph.purchased
UNION ALL SELECT 'viewed',          COUNT(*) FROM graph.viewed
UNION ALL SELECT 'uses_device',     COUNT(*) FROM graph.uses_device
UNION ALL SELECT 'uses_ip',         COUNT(*) FROM graph.uses_ip
UNION ALL SELECT 'pays_with',       COUNT(*) FROM graph.pays_with;
GO

PRINT '> graph seed tamam';
GO
