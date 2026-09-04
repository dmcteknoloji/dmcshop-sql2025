-- ============================================================================
-- 21-rag-assistant.sql
-- Senaryo 2: RAG asistanı uçtan uca T-SQL ile.
--   1) Soruyu embed et
--   2) VECTOR_SEARCH ile top-K ürün getir
--   3) Bağlamı oluştur, chat completion çağır
--   4) vector.query_log'a yaz
--
-- Workshop akışı: SSMS'ten çalıştır, vector.query_log tablosunu yan pencerede
-- açık tut — her sorudan sonra yeni satırı göster.
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

-- ----------------------------------------------------------------------------
-- Örnek soru
-- ----------------------------------------------------------------------------
DECLARE @question NVARCHAR(MAX) = N'1500 TL altı ofis için ergonomik bir mouse önerir misin?';
DECLARE @top_k INT = 5;

-- ----------------------------------------------------------------------------
-- 1) Soruyu embed et
-- ----------------------------------------------------------------------------
DECLARE @vec_json NVARCHAR(MAX);
EXEC ops.sp_embed_text @text = @question, @vec_json = @vec_json OUTPUT;

DECLARE @q VECTOR(1024) = CAST(@vec_json AS VECTOR(1024));   -- ollama bge-m3 1024

-- ----------------------------------------------------------------------------
-- 2) Top-K ürün — DiskANN approximate kNN
-- ----------------------------------------------------------------------------
DECLARE @context NVARCHAR(MAX);
DECLARE @used_ids NVARCHAR(MAX);

;WITH hits AS (
    SELECT * FROM VECTOR_SEARCH(
        TABLE      = vector.product_embedding,
        COLUMN     = embedding_bge_1024,
        SIMILAR_TO = @q,
        METRIC     = 'cosine',
        TOP_N      = @top_k)
),
joined AS (
    SELECT
        h.product_id,
        p.name,
        cat.name AS cat_name,
        p.price,
        LEFT(p.description_tr, 140) AS preview,
        h.distance
    FROM hits h
    JOIN shop.product          p   ON p.product_id   = h.product_id
    JOIN shop.product_category cat ON cat.category_id = p.category_id
)
SELECT
    @context  = STRING_AGG(
        CAST('[#' + CAST(product_id AS NVARCHAR(10)) + '] ' + name + N' — ' + cat_name + N' — '
             + FORMAT(price, 'N2') + N' ₺. ' + preview AS NVARCHAR(MAX)),
        CHAR(13) + CHAR(10)
    ) WITHIN GROUP (ORDER BY distance),
    @used_ids = STRING_AGG(CAST(product_id AS NVARCHAR(10)), ',') WITHIN GROUP (ORDER BY distance)
FROM joined;

PRINT N'--- Bağlam ---';
PRINT @context;
PRINT N'';

-- ----------------------------------------------------------------------------
-- 3) Chat completion
-- ----------------------------------------------------------------------------
DECLARE @system_prompt NVARCHAR(MAX) = N'Sen DMCShop ürün asistanısın. Sadece sana verilen ürünlerden ' +
                                       N'faydalanarak yanıt ver. Listede olmayan ürünü uydurma. Türkçe ' +
                                       N'kısa cevap ver. Ürün referansı: #ürün_no.';
DECLARE @user_prompt NVARCHAR(MAX) = N'Ürünler:' + CHAR(13) + CHAR(10) + @context + CHAR(13) + CHAR(10) +
                                     N'Soru: ' + @question;

DECLARE @answer NVARCHAR(MAX);
DECLARE @t0 DATETIME2(3) = SYSUTCDATETIME();
EXEC ops.sp_chat_complete @system_prompt = @system_prompt, @user_prompt = @user_prompt, @response_text = @answer OUTPUT;
DECLARE @latency INT = DATEDIFF(MILLISECOND, @t0, SYSUTCDATETIME());

PRINT N'--- Yanıt ---';
PRINT @answer;
PRINT N'';

-- ----------------------------------------------------------------------------
-- 4) Audit
-- ----------------------------------------------------------------------------
INSERT INTO vector.query_log (query_text, provider, scenario, top_k, used_product_ids, llm_response, latency_ms)
SELECT @question, provider, 'rag', @top_k, '[' + @used_ids + ']', @answer, @latency
FROM ops.provider_config WHERE config_key = 'default_chat' AND is_active = 1;

SELECT TOP (5) query_id, scenario, provider, top_k, latency_ms,
       LEFT(query_text, 60)  AS query_preview,
       LEFT(llm_response, 120) AS response_preview
FROM   vector.query_log
ORDER BY query_id DESC;
GO
