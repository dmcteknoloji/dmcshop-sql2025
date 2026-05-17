-- ============================================================================
-- 08-create-vector-indexes.sql
-- DiskANN vector index'leri. SQL Server 2025 RTM, vector index varken tabloya
-- DML yapılmasını yasaklar — bu nedenle önce embedding'ler doldurulup, sonra
-- bu betik çalıştırılır. `dmcshop embed-products` CLI komutu bunu otomatik
-- çağırır; manuel kurulum için ayrı dosya olarak tutulur.
--
-- Not: SQL Server 2025 RTM'de yalnızca METRIC / TYPE / MAXDOP parametreleri var.
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

-- OpenAI / text-embedding-3-small (1536)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'vix_pe_openai' AND object_id = OBJECT_ID('vector.product_embedding'))
    DROP INDEX vix_pe_openai ON vector.product_embedding;
GO

IF EXISTS (SELECT 1 FROM vector.product_embedding WHERE embedding_openai_1536 IS NOT NULL)
BEGIN
    PRINT '> vix_pe_openai oluşturuluyor';
    CREATE VECTOR INDEX vix_pe_openai
    ON vector.product_embedding (embedding_openai_1536)
    WITH (METRIC = 'cosine', TYPE = 'DiskANN', MAXDOP = 4);
END
ELSE
BEGIN
    PRINT '> embedding_openai_1536 boş, vix_pe_openai oluşturulmadı';
END
GO

-- Ollama / nomic-embed-text (768)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'vix_pe_ollama' AND object_id = OBJECT_ID('vector.product_embedding'))
    DROP INDEX vix_pe_ollama ON vector.product_embedding;
GO

IF EXISTS (SELECT 1 FROM vector.product_embedding WHERE embedding_ollama_768 IS NOT NULL)
BEGIN
    PRINT '> vix_pe_ollama oluşturuluyor';
    CREATE VECTOR INDEX vix_pe_ollama
    ON vector.product_embedding (embedding_ollama_768)
    WITH (METRIC = 'cosine', TYPE = 'DiskANN', MAXDOP = 4);
END
ELSE
BEGIN
    PRINT '> embedding_ollama_768 boş, vix_pe_ollama oluşturulmadı';
END
GO
