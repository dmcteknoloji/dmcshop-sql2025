-- ============================================================================
-- 03-schema-vector.sql
-- vector.* — embedding tablosu, DiskANN index, query log.
-- İki provider iki kolon: openai_1536 (text-embedding-3-small) ve
-- ollama_768 (nomic-embed-text). Tek tablo, iki DiskANN.
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

-- ----------------------------------------------------------------------------
-- product_embedding — bir satır = bir ürün; iki provider iki kolon
-- ----------------------------------------------------------------------------
CREATE TABLE vector.product_embedding (
    product_id            INT           NOT NULL PRIMARY KEY,
    embedding_openai_1536 VECTOR(1536)  NULL,
    embedding_ollama_768  VECTOR(768)   NULL,
    source_text           NVARCHAR(MAX) NOT NULL,
    openai_model          NVARCHAR(80)  NULL,
    ollama_model          NVARCHAR(80)  NULL,
    openai_updated_at     DATETIME2(0)  NULL,
    ollama_updated_at     DATETIME2(0)  NULL,
    CONSTRAINT fk_pe_product FOREIGN KEY (product_id) REFERENCES shop.product(product_id)
);
GO

-- ----------------------------------------------------------------------------
-- DiskANN vector index'leri burada YARATILMAZ. SQL Server 2025 RTM'de:
--   "Data modification statement failed because table has a vector index on it"
-- Bu yüzden index sırası şöyle:
--   1) Bu tablo oluşur (boş)
--   2) sql/07-seed-vector.sql source_text doldurur (embedding NULL)
--   3) `dmcshop embed-products` CLI komutu embedding kolonlarını doldurur
--   4) Aynı komut son adımda CREATE VECTOR INDEX çağırır
-- Workshop akışı bu sıraya göredir; bkz. scripts/bootstrap.sh + README.
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- query_log — RAG ve semantic search çağrılarının audit'i
-- ----------------------------------------------------------------------------
CREATE TABLE vector.query_log (
    query_id         BIGINT        NOT NULL IDENTITY PRIMARY KEY,
    query_text       NVARCHAR(MAX) NOT NULL,
    provider         VARCHAR(20)   NOT NULL,
    scenario         VARCHAR(40)   NOT NULL,   -- 'semantic_search' | 'rag'
    top_k            INT           NULL,
    used_product_ids NVARCHAR(MAX) NULL,        -- JSON array
    llm_response     NVARCHAR(MAX) NULL,
    latency_ms       INT           NULL,
    created_at       DATETIME2(0)  NOT NULL CONSTRAINT df_ql_created DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX ix_query_log_scen_date ON vector.query_log(scenario, created_at DESC);
GO

PRINT '> vector.* hazır. Sıra: 04-schema-ops.sql';
GO
