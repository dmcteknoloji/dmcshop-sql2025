-- ============================================================================
-- 50-seed-book.sql
-- Showcase kitap: "SQL Server 2025: Herkes İçin, Her Rol İçin"
--   - Ürün: id 100001 (Kitap kategorisi, özel kapak görseli)
--   - Müşteri: id 100001 (Çağlar Özenç, İstanbul)
--   - Sipariş: id 990001 (yazar kendisi, sembolik)
--   - Graph node + edge + vector embedding source_text
--
-- ID aralığı 100K+ seçildi (kurumsal seed max ~51120/10050/110400 dışında).
--
-- Sonra çalıştır:
--   dmcshop embed-products --range 100001-100001 --only-missing
--   sql/08-create-vector-indexes.sql (DiskANN recreate)
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

-- DiskANN varken DML yasak — önce drop
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'vix_pe_ollama')
    DROP INDEX vix_pe_ollama ON vector.product_embedding;
GO

-- ----------------------------------------------------------------------------
-- Ürün — SQL Server 2025 kitabı
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM shop.product WHERE product_id = 100001)
INSERT INTO shop.product (product_id, sku, name, category_id, price, description_tr, description_en, is_active, created_at)
VALUES (
    100001,
    'BK-SQL2025',
    N'SQL Server 2025: Herkes İçin, Her Rol İçin',
    1,   -- Kitap kategorisi
    850.00,
    N'Çağlar Özenç ve DMC Bilgi Teknolojileri tarafından hazırlanan kapsamlı Türkçe başvuru kitabı. ' +
    N'SQL Server 2025''in yerleşik vektör arama (VECTOR + DiskANN), graf veritabanı (GRAPH MATCH, SHORTEST_PATH), ' +
    N'RAG asistanı (AI_GENERATE_EMBEDDINGS + chat completion) ve fraud ring tespiti yeteneklerini DBA''lar, ' +
    N'geliştiriciler, veri mimarları ve AI uzmanları için adım adım anlatır. 6 kısım, 32 bölüm. Türkiye ' +
    N'penceresi, KVKK ve EU AI Act uyum bandı, Türkçe AI ekosistemi (Kumru, Trendyol-LLM, BGE-M3). Mayıs 2026.',
    N'SQL Server 2025: For Everyone, For Every Role — Comprehensive Turkish reference book by Çağlar Özenç ' +
    N'and DMC Bilgi Teknolojileri. Covers vector search (VECTOR + DiskANN), graph database (GRAPH MATCH, ' +
    N'SHORTEST_PATH), RAG, and fraud detection on SQL Server 2025 across DBA, developer, data architect, ' +
    N'and AI roles. 6 parts, 32 chapters. Published May 2026.',
    1,
    '2026-05-15'
);

-- ----------------------------------------------------------------------------
-- Müşteri — Çağlar Özenç (yazar)
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM shop.customer WHERE customer_id = 100001)
INSERT INTO shop.customer (customer_id, full_name, email, city, created_at)
VALUES (100001, N'Çağlar Özenç', 'caglarozenc@gmail.com', N'İstanbul', '2026-05-15');

-- Payment method
IF NOT EXISTS (SELECT 1 FROM shop.payment_method WHERE payment_method_id = 100001)
INSERT INTO shop.payment_method (payment_method_id, customer_id, type, last4, card_fingerprint, created_at)
VALUES (100001, 100001, 'card', '0001', NULL, '2026-05-15');

-- Sipariş (sembolik — yazar kendisi)
IF NOT EXISTS (SELECT 1 FROM shop.[order] WHERE order_id = 990001)
INSERT INTO shop.[order] (order_id, customer_id, payment_method_id, device_id, order_date, status, total_amount)
VALUES (990001, 100001, 100001, NULL, '2026-05-15', 'paid', 850.00);

IF NOT EXISTS (SELECT 1 FROM shop.order_line WHERE order_id = 990001 AND product_id = 100001)
INSERT INTO shop.order_line (order_id, product_id, quantity, unit_price)
VALUES (990001, 100001, 1, 850.00);

-- ----------------------------------------------------------------------------
-- Graph NODE'ları
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM graph.product_node WHERE product_id = 100001)
INSERT INTO graph.product_node (product_id, display_name)
VALUES (100001, N'SQL Server 2025: Herkes İçin, Her Rol İçin');

IF NOT EXISTS (SELECT 1 FROM graph.customer_node WHERE customer_id = 100001)
INSERT INTO graph.customer_node (customer_id, display_name)
VALUES (100001, N'Çağlar Özenç');

IF NOT EXISTS (SELECT 1 FROM graph.payment_node WHERE payment_method_id = 100001)
INSERT INTO graph.payment_node (payment_method_id, last4_masked) VALUES (100001, '**0001');

-- ----------------------------------------------------------------------------
-- Graph EDGE'leri
-- ----------------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM graph.purchased pur
    JOIN graph.customer_node cn ON cn.$node_id = pur.$from_id
    JOIN graph.product_node  pn ON pn.$node_id = pur.$to_id
    WHERE cn.customer_id = 100001 AND pn.product_id = 100001
)
INSERT INTO graph.purchased ($from_id, $to_id, order_id, quantity, ts)
SELECT cn.$node_id, pn.$node_id, 990001, 1, '2026-05-15'
FROM   graph.customer_node cn, graph.product_node pn
WHERE  cn.customer_id = 100001 AND pn.product_id = 100001;

INSERT INTO graph.pays_with ($from_id, $to_id, ts)
SELECT cn.$node_id, payn.$node_id, '2026-05-15'
FROM   graph.customer_node cn, graph.payment_node payn
WHERE  cn.customer_id = 100001 AND payn.payment_method_id = 100001
  AND  NOT EXISTS (
      SELECT 1 FROM graph.pays_with p
      JOIN graph.customer_node c2 ON c2.$node_id = p.$from_id
      JOIN graph.payment_node  py ON py.$node_id = p.$to_id
      WHERE c2.customer_id = 100001 AND py.payment_method_id = 100001
  );

-- ----------------------------------------------------------------------------
-- Vector embedding — source_text doldur; gerçek embedding CLI ile
--
-- NOT: source_text retrieval kalitesi için elle optimize edildi:
--   - SQL Server / Microsoft / veritabanı anahtar terimleri tekrar
--   - Yazar adı ve kurum adı net yazılır (Türkçe semantic uzayda nadir)
--   - Konu başlıkları (T-SQL, vektör arama, graf, RAG, fraud) listede geçer
-- 50K templated description ortamında bu repetition keyword recall + rerank
-- birlikte kitabı doğal sorgularda öne çıkarır.
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM vector.product_embedding WHERE product_id = 100001)
INSERT INTO vector.product_embedding (product_id, source_text)
VALUES (
    100001,
    N'SQL Server 2025 kitabı. SQL Server kitabı. Microsoft SQL Server 2025 veritabanı kitabı önerisi. ' +
    N'Yazar Çağlar Özenç ve DMC Bilgi Teknolojileri. Türkçe başvuru kitabı, ders kitabı, eğitim kaynağı. ' +
    N'SQL Server, T-SQL, veritabanı yönetimi, vektör arama, graf veritabanı, RAG asistan, fraud ring ' +
    N'tespiti konularını DBA''lar, geliştirici, veri mimarı ve AI uzmanları için adım adım anlatır. ' +
    N'6 kısım, 32 bölüm. Türkiye penceresi, KVKK, AI Act. Mayıs 2026 yayını.'
);

PRINT N'> SQL Server 2025 kitabı eklendi (ürün 100001, müşteri 100001, sipariş 990001)';
PRINT N'> Sıra: dmcshop embed-products --range 100001-100001 --only-missing';
PRINT N'> Sonra: sql/08-create-vector-indexes.sql (DiskANN recreate)';

SELECT product_id, name, price FROM shop.product WHERE product_id = 100001;
SELECT customer_id, full_name FROM shop.customer WHERE customer_id = 100001;
SELECT order_id, total_amount FROM shop.[order] WHERE order_id = 990001;
GO
