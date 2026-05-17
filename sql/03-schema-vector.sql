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
-- DiskANN vector index'leri
-- Not: SQL Server 2025 RTM'de yalnızca METRIC / TYPE / MAXDOP parametreleri var.
-- MAX_NEIGHBORS_PER_VERTEX, ALPHA gibi tuning parametreleri public yüzeyde yok.
-- Minimum 100 satır gerekir; seed (07-seed-vector.sql) bunu garantiler.
-- ----------------------------------------------------------------------------

CREATE VECTOR INDEX vix_pe_openai
ON vector.product_embedding (embedding_openai_1536)
WITH (METRIC = 'cosine', TYPE = 'DiskANN', MAXDOP = 4);
GO

CREATE VECTOR INDEX vix_pe_ollama
ON vector.product_embedding (embedding_ollama_768)
WITH (METRIC = 'cosine', TYPE = 'DiskANN', MAXDOP = 4);
GO

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
