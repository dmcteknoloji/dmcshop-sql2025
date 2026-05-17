-- ============================================================================
-- 31-seed-large-customers.sql
-- 10.000 müşteri (customer_id 51-10050) + ~12.000 payment_method.
-- Türkçe rastgele isim üreteci (ad + soyad listesi CROSS JOIN).
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

DECLARE @first_name TABLE (idx INT IDENTITY(1,1), w NVARCHAR(40));
INSERT INTO @first_name VALUES
    -- Erkek
    (N'Ahmet'),(N'Ali'),(N'Hasan'),(N'Hüseyin'),(N'Mehmet'),(N'Mustafa'),(N'İbrahim'),(N'İsmail'),
    (N'Murat'),(N'Burak'),(N'Emre'),(N'Furkan'),(N'Mert'),(N'Tolga'),(N'Volkan'),(N'Onur'),
    (N'Hakan'),(N'Kerem'),(N'Berkay'),(N'Yiğit'),(N'Eren'),(N'Doruk'),(N'Arda'),(N'Mete'),
    (N'Kaan'),(N'Tuncay'),(N'Cem'),(N'Sinan'),(N'Furkan'),(N'Barış'),(N'Ozan'),(N'Yusuf'),
    (N'Ömer'),(N'Cihan'),(N'Bora'),(N'Anıl'),(N'Erkan'),(N'Levent'),(N'Selim'),(N'Tarık'),
    -- Kadın
    (N'Ayşe'),(N'Fatma'),(N'Zeynep'),(N'Elif'),(N'Selin'),(N'Canan'),(N'Pınar'),(N'Gizem'),
    (N'Berna'),(N'Aslı'),(N'Sevgi'),(N'Gül'),(N'Esra'),(N'Nazlı'),(N'Melike'),(N'İlayda'),
    (N'Damla'),(N'Buse'),(N'Sude'),(N'Ece'),(N'Defne'),(N'Lale'),(N'Beste'),(N'Ada'),
    (N'İrem'),(N'Sema'),(N'Deniz'),(N'Banu'),(N'Eda'),(N'Hale'),(N'Yeliz'),(N'Tuğçe'),
    (N'Merve'),(N'Senem'),(N'Tuba'),(N'Şirin'),(N'Yelda'),(N'Sibel'),(N'Hülya'),(N'Nur');

DECLARE @last_name TABLE (idx INT IDENTITY(1,1), w NVARCHAR(40));
INSERT INTO @last_name VALUES
    (N'Yılmaz'),(N'Kaya'),(N'Demir'),(N'Çelik'),(N'Şahin'),(N'Yıldız'),(N'Yıldırım'),(N'Öztürk'),
    (N'Aydın'),(N'Özdemir'),(N'Arslan'),(N'Doğan'),(N'Kılıç'),(N'Aslan'),(N'Çetin'),(N'Kara'),
    (N'Koç'),(N'Kurt'),(N'Özkan'),(N'Şimşek'),(N'Polat'),(N'Erdoğan'),(N'Aksoy'),(N'Acar'),
    (N'Bayram'),(N'Bozkurt'),(N'Ergin'),(N'Türk'),(N'Sarı'),(N'Uçar'),(N'Tan'),(N'Yalçın'),
    (N'Erdem'),(N'Güneş'),(N'Yiğit'),(N'Şen'),(N'Karaca'),(N'Akın'),(N'Akkaya'),(N'Yavuz'),
    (N'Önal'),(N'Çevik'),(N'Akar'),(N'Tekin'),(N'Uğur'),(N'Korkmaz'),(N'Ünal'),(N'Bilgin'),
    (N'Erol'),(N'Karadağ'),(N'Demirci'),(N'Çakır'),(N'Kaplan'),(N'Bulut'),(N'Yaman'),(N'Aktaş');

DECLARE @city TABLE (idx INT IDENTITY(1,1), w NVARCHAR(40));
INSERT INTO @city VALUES
    (N'İstanbul'),(N'Ankara'),(N'İzmir'),(N'Bursa'),(N'Antalya'),(N'Adana'),(N'Konya'),(N'Gaziantep'),
    (N'Kayseri'),(N'Trabzon'),(N'Mersin'),(N'Eskişehir'),(N'Diyarbakır'),(N'Samsun'),(N'Denizli'),(N'Sakarya'),
    (N'Şanlıurfa'),(N'Hatay'),(N'Kocaeli'),(N'Manisa'),(N'Balıkesir'),(N'Tekirdağ'),(N'Aydın'),(N'Muğla');

-- 10.000 müşteri üret
WITH numbers AS (
    SELECT TOP (10000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects o1
    CROSS JOIN sys.all_objects o2
)
INSERT INTO shop.customer (customer_id, full_name, email, city, created_at)
SELECT
    50 + n AS customer_id,
    fn.w + N' ' + ln.w AS full_name,
    'demo' + CAST(50 + n AS VARCHAR(10)) + '@example.com' AS email,
    ct.w AS city,
    DATEADD(MINUTE, (n * 47) % (365 * 24 * 60), '2026-01-01') AS created_at
FROM   numbers num
JOIN   @first_name fn ON fn.idx = ((num.n - 1) % 80) + 1
JOIN   @last_name  ln ON ln.idx = (((num.n - 1) / 80) % 56) + 1
JOIN   @city       ct ON ct.idx = ((num.n - 1) % 24) + 1;

PRINT '> 10.000 müşteri eklendi (customer_id 51..10050)';

-- ----------------------------------------------------------------------------
-- Payment methods (her müşteri için ortalama 1.2 kart)
-- ----------------------------------------------------------------------------

WITH numbers AS (
    SELECT TOP (12000) 50 + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS pmid
    FROM sys.all_objects o1 CROSS JOIN sys.all_objects o2
)
INSERT INTO shop.payment_method (payment_method_id, customer_id, type, last4, card_fingerprint, created_at)
SELECT
    n.pmid AS payment_method_id,
    50 + ((n.pmid - 50 - 1) % 10000) + 1 AS customer_id,
    'card' AS type,
    RIGHT('0000' + CAST(n.pmid AS VARCHAR(10)), 4) AS last4,
    CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CAST(n.pmid AS VARCHAR(20))), 2) AS card_fingerprint,
    DATEADD(MINUTE, ((n.pmid - 50) * 31) % (365 * 24 * 60), '2026-01-01')
FROM numbers n;

PRINT '> ~12.000 ek payment_method eklendi';

-- Doğrulama
SELECT 'customer (total)' AS entity, COUNT(*) AS n FROM shop.customer
UNION ALL SELECT 'payment_method', COUNT(*) FROM shop.payment_method;
GO
