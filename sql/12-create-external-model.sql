-- ============================================================================
-- 12-create-external-model.sql
-- AI_GENERATE_EMBEDDINGS çağrılarında kullanılan external model tanımları.
--
-- Workshop için: sql/20-vector-search.sql, 21-rag-assistant.sql,
-- 24-personalized.sql gibi T-SQL dosyalarında doğrudan T-SQL'den embedding
-- üretebilmek için. .NET uygulaması bu modelleri kullanmaz (kendi
-- IEmbeddingProvider üzerinden gider).
--
-- Önkoşul:
--   sp_configure 'external rest endpoint enabled' = 1 (server-wide)
--   ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON
--   (00-database-create.sql zaten açar)
-- ============================================================================

USE master;
GO

-- Server-wide: external REST endpoint çağrıları aktif olmalı
IF (SELECT value FROM sys.configurations WHERE name = 'external rest endpoint enabled') = 0
BEGIN
    EXEC sp_configure 'external rest endpoint enabled', 1;
    RECONFIGURE;
    PRINT '> sp_configure ''external rest endpoint enabled'' = 1';
END
GO

USE dmcshop;
GO
SET NOCOUNT ON;
GO

-- ----------------------------------------------------------------------------
-- ollama_embed_text — nomic-embed-text üzerinden 768 dim embedding
-- ----------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM sys.external_models WHERE name = 'ollama_embed_text')
    DROP EXTERNAL MODEL ollama_embed_text;
GO

CREATE EXTERNAL MODEL ollama_embed_text
WITH (
    LOCATION   = 'http://host.docker.internal:11434/api/embeddings',
    API_FORMAT = 'Ollama',
    MODEL_TYPE = EMBEDDINGS,
    MODEL      = 'nomic-embed-text'
);
GO

PRINT '> EXTERNAL MODEL ollama_embed_text hazır';

-- ----------------------------------------------------------------------------
-- ollama_chat_qwen — qwen2.5:3b-instruct üzerinden chat
-- ----------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM sys.external_models WHERE name = 'ollama_chat_qwen')
    DROP EXTERNAL MODEL ollama_chat_qwen;
GO

CREATE EXTERNAL MODEL ollama_chat_qwen
WITH (
    LOCATION   = 'http://host.docker.internal:11434/api/chat',
    API_FORMAT = 'Ollama',
    MODEL_TYPE = CHAT_COMPLETIONS,
    MODEL      = 'qwen2.5:3b-instruct-q4_K_M'
);
GO

PRINT '> EXTERNAL MODEL ollama_chat_qwen hazır';

-- ----------------------------------------------------------------------------
-- Test
-- ----------------------------------------------------------------------------
DECLARE @v VECTOR(768) = AI_GENERATE_EMBEDDINGS(N'test merhaba' USE MODEL ollama_embed_text);
SELECT LEN(CAST(@v AS NVARCHAR(MAX))) AS embedding_json_length;
GO

PRINT '> External model setup tamamlandı';
PRINT '> Sıra: sql/20, 21, 24 dosyalarındaki AI_GENERATE_EMBEDDINGS çağrıları artık çalışır';
GO
