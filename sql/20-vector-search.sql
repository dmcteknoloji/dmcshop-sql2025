-- ============================================================================
-- 20-vector-search.sql
-- Senaryo 1: Semantic product search — VECTOR_SEARCH + DiskANN.
-- LIKE ile lexical aramanın "rahat klavye" sorgusunda sıfır sonuç verdiğini,
-- vector search'ün ise anlam üzerinden ürün bulduğunu kontrast olarak gösterir.
--
-- Önkoşul:
--   - 05-07 seed dosyaları çalıştırıldı
--   - vector.product_embedding.embedding_openai_1536 dolduruldu
--     (dotnet run --project app/src/DMCShop.Cli -- embed-products --provider openai)
--   - CREATE EXTERNAL MODEL openai_embed_small kuruldu
--     (M3: 10-sp-embed.sql veya CLI 'dmcshop config set-provider openai')
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

DECLARE @query_text NVARCHAR(MAX) = N'rahat ergonomik klavye';

-- ----------------------------------------------------------------------------
-- (a) Önce LIKE — lexical eşleşme. "rahat klavye" tam metin geçmiyor;
-- description_tr'de "klavye" ya da "ergonomik" geçenler tek tek arandığında
-- yine de bu sorguya semantic karşılık veren ürünleri bulamaz.
-- ----------------------------------------------------------------------------
PRINT '> LIKE ile arama (lexical)';

SELECT TOP (10)
    product_id,
    name,
    LEFT(description_tr, 80) AS preview
FROM shop.product
WHERE name LIKE N'%' + @query_text + N'%'
   OR description_tr LIKE N'%' + @query_text + N'%';
-- Beklenen: 0 satır. "rahat ergonomik klavye" tam ifadesi metinlerde yok.

-- Tek tek kelimelerle bile çoğunlukla daha geniş eşleşmeler getirmez:
SELECT TOP (10)
    product_id,
    name,
    LEFT(description_tr, 80) AS preview
FROM shop.product
WHERE description_tr LIKE N'%klavye%';
-- Beklenen: ürün 1021 (Mekanik Klavye Cherry MX Brown) tek başına gelir.
GO

-- ----------------------------------------------------------------------------
-- (b) VECTOR_SEARCH — anlamsal arama. AI_GENERATE_EMBEDDINGS sorgu metnini
-- vektöre çevirir, DiskANN approximate kNN top 5 sonucu döner. "rahat",
-- "ergonomik", "klavye" kavramları semantic uzayda yakın olan ürünleri
-- yakalar — mekanik klavye, Logitech mouse, mouse pad, kulaklık gibi.
-- ----------------------------------------------------------------------------
PRINT '> VECTOR_SEARCH ile arama (semantic)';

DECLARE @query_text2 NVARCHAR(MAX) = N'rahat ergonomik klavye';

DECLARE @q VECTOR(1536) = AI_GENERATE_EMBEDDINGS(
    @query_text2 USE MODEL openai_embed_small
);

SELECT TOP (5) WITH APPROXIMATE
    vs.product_id,
    p.name,
    cat.name AS category,
    p.price,
    vs.distance,
    LEFT(p.description_tr, 100) AS preview
FROM VECTOR_SEARCH(
    TABLE      = vector.product_embedding,
    COLUMN     = embedding_openai_1536,
    SIMILAR_TO = @q,
    METRIC     = 'cosine'
) AS vs
JOIN shop.product          p   ON p.product_id   = vs.product_id
JOIN shop.product_category cat ON cat.category_id = p.category_id
ORDER BY vs.distance ASC;
GO

-- ----------------------------------------------------------------------------
-- (c) Aynı şey provider'ı değiştirerek (ollama 768 dim) — ops.provider_config
-- 'default_embed' = 'ollama' iken external model 'ollama_embed_text' kullanır.
-- ----------------------------------------------------------------------------
/*
DECLARE @query_text3 NVARCHAR(MAX) = N'rahat ergonomik klavye';

DECLARE @qo VECTOR(768) = AI_GENERATE_EMBEDDINGS(
    @query_text3 USE MODEL ollama_embed_text
);

SELECT TOP (5) WITH APPROXIMATE
    vs.product_id,
    p.name,
    vs.distance
FROM VECTOR_SEARCH(
    TABLE      = vector.product_embedding,
    COLUMN     = embedding_ollama_768,
    SIMILAR_TO = @qo,
    METRIC     = 'cosine'
) AS vs
JOIN shop.product p ON p.product_id = vs.product_id
ORDER BY vs.distance ASC;
*/
GO
