-- ============================================================================
-- 01-schema-shop.sql
-- shop.* — e-ticaret çekirdek tabloları (relational).
-- Hiçbir tablo VECTOR veya GRAPH değildir; saf relational.
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

-- ----------------------------------------------------------------------------
-- product_category — basit hiyerarşi (self-referencing)
-- ----------------------------------------------------------------------------
CREATE TABLE shop.product_category (
    category_id        INT          NOT NULL PRIMARY KEY,
    name               NVARCHAR(120) NOT NULL,
    parent_category_id INT          NULL,
    created_at         DATETIME2(0) NOT NULL CONSTRAINT df_cat_created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT fk_cat_parent
        FOREIGN KEY (parent_category_id) REFERENCES shop.product_category(category_id)
);
GO

-- ----------------------------------------------------------------------------
-- product — embedding edilen description_tr / description_en burada yaşar
-- ----------------------------------------------------------------------------
CREATE TABLE shop.product (
    product_id     INT            NOT NULL PRIMARY KEY,
    sku            VARCHAR(32)    NOT NULL,
    name           NVARCHAR(200)  NOT NULL,
    category_id    INT            NOT NULL,
    price          DECIMAL(12, 2) NOT NULL CHECK (price >= 0),
    description_tr NVARCHAR(MAX)  NOT NULL,
    description_en NVARCHAR(MAX)  NULL,
    is_active      BIT            NOT NULL CONSTRAINT df_product_active DEFAULT 1,
    created_at     DATETIME2(0)   NOT NULL CONSTRAINT df_product_created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT uq_product_sku UNIQUE (sku),
    CONSTRAINT fk_product_category
        FOREIGN KEY (category_id) REFERENCES shop.product_category(category_id)
);
GO

CREATE INDEX ix_product_category ON shop.product(category_id) INCLUDE (price, is_active);
GO

-- ----------------------------------------------------------------------------
-- customer
-- ----------------------------------------------------------------------------
CREATE TABLE shop.customer (
    customer_id INT           NOT NULL PRIMARY KEY,
    full_name   NVARCHAR(160) NOT NULL,
    email       VARCHAR(254)  NOT NULL,
    city        NVARCHAR(80)  NULL,
    created_at  DATETIME2(0)  NOT NULL CONSTRAINT df_customer_created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT uq_customer_email UNIQUE (email)
);
GO

-- ----------------------------------------------------------------------------
-- payment_method — card_fingerprint, fraud senaryosunda "aynı kart farklı hesap"
-- pattern'ini gösterir. PAN değil, SHA-256 fingerprint.
-- ----------------------------------------------------------------------------
CREATE TABLE shop.payment_method (
    payment_method_id BIGINT       NOT NULL PRIMARY KEY,
    customer_id       INT          NOT NULL,
    type              VARCHAR(20)  NOT NULL CHECK (type IN ('card', 'bank', 'wallet')),
    last4             CHAR(4)      NULL,
    card_fingerprint  CHAR(64)     NULL,
    created_at        DATETIME2(0) NOT NULL CONSTRAINT df_pm_created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT fk_pm_customer
        FOREIGN KEY (customer_id) REFERENCES shop.customer(customer_id)
);
GO

CREATE INDEX ix_pm_customer     ON shop.payment_method(customer_id);
CREATE INDEX ix_pm_card_finger  ON shop.payment_method(card_fingerprint) WHERE card_fingerprint IS NOT NULL;
GO

-- ----------------------------------------------------------------------------
-- device — IP, fingerprint, user agent. Fraud için critical.
-- ----------------------------------------------------------------------------
CREATE TABLE shop.device (
    device_id   BIGINT        NOT NULL PRIMARY KEY,
    fingerprint CHAR(64)      NOT NULL,
    ip_address  NVARCHAR(45)  NOT NULL,
    user_agent  NVARCHAR(400) NULL,
    first_seen  DATETIME2(0)  NOT NULL,
    last_seen   DATETIME2(0)  NOT NULL,
    CONSTRAINT uq_device_fingerprint UNIQUE (fingerprint)
);
GO

CREATE INDEX ix_device_ip ON shop.device(ip_address);
GO

-- ----------------------------------------------------------------------------
-- customer_device — çok-çoğa; aynı device 5 hesap işletiyor pattern'i
-- ----------------------------------------------------------------------------
CREATE TABLE shop.customer_device (
    customer_id INT          NOT NULL,
    device_id   BIGINT       NOT NULL,
    first_seen  DATETIME2(0) NOT NULL,
    last_seen   DATETIME2(0) NOT NULL,
    CONSTRAINT pk_customer_device PRIMARY KEY (customer_id, device_id),
    CONSTRAINT fk_cd_customer FOREIGN KEY (customer_id) REFERENCES shop.customer(customer_id),
    CONSTRAINT fk_cd_device   FOREIGN KEY (device_id)   REFERENCES shop.device(device_id)
);
GO

-- ----------------------------------------------------------------------------
-- order (rezerve keyword olduğundan delimited identifier — kitap pattern'iyle aynı)
-- ----------------------------------------------------------------------------
CREATE TABLE shop.[order] (
    order_id          BIGINT         NOT NULL PRIMARY KEY,
    customer_id       INT            NOT NULL,
    payment_method_id BIGINT         NOT NULL,
    device_id         BIGINT         NULL,
    order_date        DATETIME2(0)   NOT NULL,
    status            VARCHAR(20)    NOT NULL CHECK (status IN ('pending', 'paid', 'shipped', 'cancelled', 'refunded')),
    total_amount      DECIMAL(14, 2) NOT NULL CHECK (total_amount >= 0),
    CONSTRAINT fk_order_customer FOREIGN KEY (customer_id)       REFERENCES shop.customer(customer_id),
    CONSTRAINT fk_order_payment  FOREIGN KEY (payment_method_id) REFERENCES shop.payment_method(payment_method_id),
    CONSTRAINT fk_order_device   FOREIGN KEY (device_id)         REFERENCES shop.device(device_id)
);
GO

CREATE INDEX ix_order_customer  ON shop.[order](customer_id) INCLUDE (order_date, total_amount);
CREATE INDEX ix_order_date      ON shop.[order](order_date);
GO

-- ----------------------------------------------------------------------------
-- order_line
-- ----------------------------------------------------------------------------
CREATE TABLE shop.order_line (
    order_id   BIGINT         NOT NULL,
    product_id INT            NOT NULL,
    quantity   INT            NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(12, 2) NOT NULL CHECK (unit_price >= 0),
    CONSTRAINT pk_order_line PRIMARY KEY (order_id, product_id),
    CONSTRAINT fk_ol_order   FOREIGN KEY (order_id)   REFERENCES shop.[order](order_id),
    CONSTRAINT fk_ol_product FOREIGN KEY (product_id) REFERENCES shop.product(product_id)
);
GO

-- ----------------------------------------------------------------------------
-- product_view — co-purchase / recommendation için izleme
-- ----------------------------------------------------------------------------
CREATE TABLE shop.product_view (
    view_id     BIGINT       NOT NULL IDENTITY PRIMARY KEY,
    customer_id INT          NOT NULL,
    product_id  INT          NOT NULL,
    viewed_at   DATETIME2(0) NOT NULL,
    CONSTRAINT fk_pv_customer FOREIGN KEY (customer_id) REFERENCES shop.customer(customer_id),
    CONSTRAINT fk_pv_product  FOREIGN KEY (product_id)  REFERENCES shop.product(product_id)
);
GO

CREATE INDEX ix_pv_customer_date ON shop.product_view(customer_id, viewed_at DESC);
CREATE INDEX ix_pv_product_date  ON shop.product_view(product_id,  viewed_at DESC);
GO

PRINT '> shop.* hazır. Sıra: 02-schema-graph.sql';
GO
