-- ============================================================================
-- 07-seed-vector.sql
-- vector.product_embedding satırlarını oluştur — source_text doldurulur,
-- embedding kolonları NULL kalır. Embedding'ler `dmcshop embed-products`
-- CLI komutu ile veya provider ne olursa uygun source_text üzerinden
-- runtime'da hesaplanır.
--
-- Bu ayrım workshop kurulumunu basitleştirir: ham veri repo'ya commit
-- edilir, embedding üretimi katılımcının kendi provider'ında çalıştırılır.
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

INSERT INTO vector.product_embedding (product_id, source_text)
SELECT
    p.product_id,
    CONCAT(
        p.name, N'. ',
        c.name, N'. ',
        p.description_tr,
        N' / ',
        ISNULL(p.description_en, N'')
    )
FROM shop.product p
JOIN shop.product_category c ON c.category_id = p.category_id;

PRINT '> vector.product_embedding source_text dolduruldu (embedding kolonları NULL)';
PRINT '> Sıra: dotnet run --project app/src/DMCShop.Cli -- embed-products --provider <openai|ollama>';

SELECT
    COUNT(*) AS row_count,
    SUM(CASE WHEN embedding_openai_1536 IS NOT NULL THEN 1 ELSE 0 END) AS openai_filled,
    SUM(CASE WHEN embedding_ollama_768  IS NOT NULL THEN 1 ELSE 0 END) AS ollama_filled
FROM vector.product_embedding;
GO
