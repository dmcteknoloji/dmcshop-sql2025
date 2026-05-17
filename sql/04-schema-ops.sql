-- ============================================================================
-- 04-schema-ops.sql
-- ops.* — provider config (T-SQL ↔ .NET ortak truth), audit.
-- ops.provider_config; CLI 'dmcshop config set-provider' bu tabloyu ve
-- appsettings.Local.json'ı senkron tutar.
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

-- ----------------------------------------------------------------------------
-- provider_config
--   config_key:
--     'default_embed' — embedding üretimi için aktif provider
--     'default_chat'  — chat completion için aktif provider
--   credential_name:
--     CREATE DATABASE SCOPED CREDENTIAL adı (sp_invoke_external_rest_endpoint
--     için). NULL → kimlik gerekmiyor (örn. local Ollama).
-- ----------------------------------------------------------------------------
CREATE TABLE ops.provider_config (
    config_key      VARCHAR(40)   NOT NULL PRIMARY KEY,
    provider        VARCHAR(20)   NOT NULL CHECK (provider IN ('openai', 'ollama')),
    model_name      NVARCHAR(120) NOT NULL,
    endpoint_url    NVARCHAR(400) NOT NULL,
    credential_name NVARCHAR(200) NULL,
    is_active       BIT           NOT NULL CONSTRAINT df_pc_active DEFAULT 1,
    updated_at      DATETIME2(0)  NOT NULL CONSTRAINT df_pc_updated DEFAULT SYSUTCDATETIME()
);
GO

-- Varsayılan kayıtlar — bootstrap sonrası 'dmcshop config set-provider' ile
-- değiştirilebilir.
INSERT INTO ops.provider_config (config_key, provider, model_name, endpoint_url, credential_name)
VALUES
    ('default_embed', 'ollama', 'nomic-embed-text',     'http://host.docker.internal:11434/api/embeddings', NULL),
    ('default_chat',  'ollama', 'llama3.1:8b-instruct', 'http://host.docker.internal:11434/api/chat',       NULL);
GO

-- ----------------------------------------------------------------------------
-- rest_call_log — sp_invoke_external_rest_endpoint çağrılarının izlemesi
-- (debug ve workshop'ta canlı tablo göstermek için)
-- ----------------------------------------------------------------------------
CREATE TABLE ops.rest_call_log (
    call_id      BIGINT        NOT NULL IDENTITY PRIMARY KEY,
    provider     VARCHAR(20)   NOT NULL,
    endpoint_url NVARCHAR(400) NOT NULL,
    http_status  INT           NULL,
    latency_ms   INT           NULL,
    error_text   NVARCHAR(MAX) NULL,
    created_at   DATETIME2(0)  NOT NULL CONSTRAINT df_rcl_created DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX ix_rcl_date ON ops.rest_call_log(created_at DESC);
GO

PRINT '> ops.* hazır. Tüm schema''lar yaratıldı.';
PRINT '> Sıra: 05-seed-shop.sql (Milestone 2''de eklenecek)';
GO
