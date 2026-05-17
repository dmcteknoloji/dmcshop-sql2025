-- ============================================================================
-- 02-schema-graph.sql
-- graph.* — NODE/EDGE tabloları; shop'taki entity'lere FK ile köprü.
-- Tasarım kararı: NODE'lar minimal (sadece $node_id + FK + 1 display alan).
-- Veri shop'tan synthesize edilir (06-seed-graph.sql), kopyalanmaz.
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

-- ----------------------------------------------------------------------------
-- NODE tabloları
-- ----------------------------------------------------------------------------

CREATE TABLE graph.customer_node (
    customer_id  INT           NOT NULL PRIMARY KEY,
    display_name NVARCHAR(160) NOT NULL,
    CONSTRAINT fk_cn_customer FOREIGN KEY (customer_id) REFERENCES shop.customer(customer_id)
) AS NODE;
GO

CREATE TABLE graph.product_node (
    product_id   INT           NOT NULL PRIMARY KEY,
    display_name NVARCHAR(200) NOT NULL,
    CONSTRAINT fk_pn_product FOREIGN KEY (product_id) REFERENCES shop.product(product_id)
) AS NODE;
GO

CREATE TABLE graph.device_node (
    device_id          BIGINT      NOT NULL PRIMARY KEY,
    fingerprint_short  CHAR(12)    NOT NULL,
    CONSTRAINT fk_dn_device FOREIGN KEY (device_id) REFERENCES shop.device(device_id)
) AS NODE;
GO

CREATE TABLE graph.payment_node (
    payment_method_id BIGINT  NOT NULL PRIMARY KEY,
    last4_masked      CHAR(8) NOT NULL,   -- '**1234'
    CONSTRAINT fk_payn_pm FOREIGN KEY (payment_method_id) REFERENCES shop.payment_method(payment_method_id)
) AS NODE;
GO

-- IP shop'ta sadece kolon değeri; graph'ta düğüm olması fraud için kritik
CREATE TABLE graph.ip_node (
    ip_node_id BIGINT       NOT NULL IDENTITY PRIMARY KEY,
    ip_address NVARCHAR(45) NOT NULL,
    CONSTRAINT uq_ipn UNIQUE (ip_address)
) AS NODE;
GO

-- ----------------------------------------------------------------------------
-- EDGE tabloları
--   purchased    : customer → product   (sipariş bağlamıyla)
--   viewed       : customer → product   (browsing)
--   uses_device  : customer → device
--   uses_ip      : device   → ip
--   pays_with    : customer → payment_method
-- ----------------------------------------------------------------------------

CREATE TABLE graph.purchased (
    order_id   BIGINT       NOT NULL,
    quantity   INT          NOT NULL,
    ts         DATETIME2(0) NOT NULL,
    CONSTRAINT ec_purchased CONNECTION (graph.customer_node TO graph.product_node)
) AS EDGE;
GO

CREATE TABLE graph.viewed (
    ts DATETIME2(0) NOT NULL,
    CONSTRAINT ec_viewed CONNECTION (graph.customer_node TO graph.product_node)
) AS EDGE;
GO

CREATE TABLE graph.uses_device (
    first_seen DATETIME2(0) NOT NULL,
    last_seen  DATETIME2(0) NOT NULL,
    CONSTRAINT ec_uses_device CONNECTION (graph.customer_node TO graph.device_node)
) AS EDGE;
GO

CREATE TABLE graph.uses_ip (
    ts DATETIME2(0) NOT NULL,
    CONSTRAINT ec_uses_ip CONNECTION (graph.device_node TO graph.ip_node)
) AS EDGE;
GO

CREATE TABLE graph.pays_with (
    ts DATETIME2(0) NOT NULL,
    CONSTRAINT ec_pays_with CONNECTION (graph.customer_node TO graph.payment_node)
) AS EDGE;
GO

PRINT '> graph.* hazır. Sıra: 03-schema-vector.sql';
GO
