-- ============================================================================
-- 33-seed-large-graph.sql
-- Yeni shop verisini graph tablolarına yansıtır.
-- Mevcut graph satırları KORUNUR (sadece eksik olanlar eklenir).
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

-- ----------------------------------------------------------------------------
-- NODE tabloları — yeni müşteri, ürün, device, payment, IP
-- ----------------------------------------------------------------------------

INSERT INTO graph.customer_node (customer_id, display_name)
SELECT c.customer_id, c.full_name
FROM   shop.customer c
WHERE  NOT EXISTS (SELECT 1 FROM graph.customer_node cn WHERE cn.customer_id = c.customer_id);

INSERT INTO graph.product_node (product_id, display_name)
SELECT p.product_id, p.name
FROM   shop.product p
WHERE  NOT EXISTS (SELECT 1 FROM graph.product_node pn WHERE pn.product_id = p.product_id);

INSERT INTO graph.device_node (device_id, fingerprint_short)
SELECT d.device_id, LEFT(d.fingerprint, 12)
FROM   shop.device d
WHERE  NOT EXISTS (SELECT 1 FROM graph.device_node dn WHERE dn.device_id = d.device_id);

INSERT INTO graph.payment_node (payment_method_id, last4_masked)
SELECT pm.payment_method_id, '**' + pm.last4
FROM   shop.payment_method pm
WHERE  pm.last4 IS NOT NULL
  AND  NOT EXISTS (SELECT 1 FROM graph.payment_node pn WHERE pn.payment_method_id = pm.payment_method_id);

INSERT INTO graph.ip_node (ip_address)
SELECT DISTINCT d.ip_address
FROM   shop.device d
WHERE  NOT EXISTS (SELECT 1 FROM graph.ip_node ipn WHERE ipn.ip_address = d.ip_address);

PRINT '> NODE''lar genişletildi';

-- ----------------------------------------------------------------------------
-- EDGE — yeni siparişler için purchased + uses_device + uses_ip
-- ----------------------------------------------------------------------------

-- purchased
INSERT INTO graph.purchased ($from_id, $to_id, order_id, quantity, ts)
SELECT cn.$node_id, pn.$node_id, ol.order_id, ol.quantity, o.order_date
FROM   shop.order_line ol
JOIN   shop.[order]         o  ON o.order_id      = ol.order_id
JOIN   graph.customer_node  cn ON cn.customer_id  = o.customer_id
JOIN   graph.product_node   pn ON pn.product_id   = ol.product_id
WHERE  o.order_id > 10400;   -- yeni siparişler

-- uses_device
INSERT INTO graph.uses_device ($from_id, $to_id, first_seen, last_seen)
SELECT cn.$node_id, dn.$node_id, cd.first_seen, cd.last_seen
FROM   shop.customer_device cd
JOIN   graph.customer_node  cn ON cn.customer_id = cd.customer_id
JOIN   graph.device_node    dn ON dn.device_id   = cd.device_id
WHERE  cd.customer_id > 50;

-- uses_ip (yeni device → IP)
INSERT INTO graph.uses_ip ($from_id, $to_id, ts)
SELECT dn.$node_id, ipn.$node_id, d.first_seen
FROM   shop.device          d
JOIN   graph.device_node    dn  ON dn.device_id  = d.device_id
JOIN   graph.ip_node        ipn ON ipn.ip_address = d.ip_address
WHERE  d.device_id >= 300;

-- pays_with (yeni payment_method)
INSERT INTO graph.pays_with ($from_id, $to_id, ts)
SELECT cn.$node_id, payn.$node_id, pm.created_at
FROM   shop.payment_method  pm
JOIN   graph.customer_node  cn   ON cn.customer_id        = pm.customer_id
JOIN   graph.payment_node   payn ON payn.payment_method_id = pm.payment_method_id
WHERE  pm.payment_method_id >= 51;

PRINT '> EDGE''ler genişletildi';

-- Doğrulama
SELECT 'customer_node' AS entity, COUNT(*) AS n FROM graph.customer_node
UNION ALL SELECT 'product_node',  COUNT(*) FROM graph.product_node
UNION ALL SELECT 'device_node',   COUNT(*) FROM graph.device_node
UNION ALL SELECT 'payment_node',  COUNT(*) FROM graph.payment_node
UNION ALL SELECT 'ip_node',       COUNT(*) FROM graph.ip_node
UNION ALL SELECT 'purchased',     COUNT(*) FROM graph.purchased
UNION ALL SELECT 'uses_device',   COUNT(*) FROM graph.uses_device
UNION ALL SELECT 'uses_ip',       COUNT(*) FROM graph.uses_ip
UNION ALL SELECT 'pays_with',     COUNT(*) FROM graph.pays_with;
GO
