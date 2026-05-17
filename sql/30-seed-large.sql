-- ============================================================================
-- 30-seed-large.sql
-- "Kurumsal ölçek" seed: 100 kategori (94 yeni) + 50.000 ürün (1121-51120).
-- Mevcut 120 showcase ürün (1001-1120) ve 6 kategori KORUNUR.
--
-- T-SQL CROSS JOIN tabanlı sentetik üreteç: kategori başına ortalama 500 ürün,
-- {sıfat × isim × varyant} kompozisyonu.
--
-- Çalıştırma süresi: B2ms üzerinde ~30-60 sn.
-- Embedding'ler bu adımda üretilmez; sonradan:
--   dotnet run --project app/src/DMCShop.Cli -- embed-products --range 1121-
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

-- ----------------------------------------------------------------------------
-- 94 ek kategori (7..100). Mevcut 1..6 KORUNUR.
-- 10 ana kategori grubu × 10 alt = 100 (mevcut 6 + 94 yeni).
-- ----------------------------------------------------------------------------

INSERT INTO shop.product_category (category_id, name, parent_category_id, created_at)
SELECT
    7 + ROW_NUMBER() OVER (ORDER BY group_no, sub_no) - 1 AS category_id,
    name,
    NULL,
    '2026-01-01'
FROM (VALUES
    -- Kitap genişlemesi (alt kategoriler)
    (1, 1,  N'Roman'),                 (1, 2,  N'Şiir'),
    (1, 3,  N'Tarih'),                 (1, 4,  N'Bilim'),
    (1, 5,  N'Felsefe'),               (1, 6,  N'Çocuk'),
    (1, 7,  N'Çizgi Roman'),           (1, 8,  N'Akademik'),
    (1, 9,  N'Yemek Kitabı'),

    -- Elektronik (alt)
    (2, 1,  N'Klavye'),                (2, 2,  N'Mouse'),
    (2, 3,  N'Monitör'),               (2, 4,  N'Kulaklık'),
    (2, 5,  N'Tablet'),                (2, 6,  N'Telefon'),
    (2, 7,  N'Akıllı Saat'),           (2, 8,  N'Hoparlör'),
    (2, 9,  N'Yazıcı'),                (2, 10, N'Kamera'),
    (2, 11, N'Aksesuar'),

    -- Gıda (alt)
    (3, 1,  N'Kahve'),                 (3, 2,  N'Çay'),
    (3, 3,  N'Çikolata'),              (3, 4,  N'Bal ve Reçel'),
    (3, 5,  N'Zeytinyağı'),            (3, 6,  N'Kuruyemiş'),
    (3, 7,  N'Baharat'),               (3, 8,  N'Süt Ürünleri'),
    (3, 9,  N'Atıştırmalık'),

    -- Giyim (alt)
    (4, 1,  N'Erkek Üst Giyim'),       (4, 2,  N'Erkek Alt Giyim'),
    (4, 3,  N'Erkek Ayakkabı'),        (4, 4,  N'Kadın Üst Giyim'),
    (4, 5,  N'Kadın Alt Giyim'),       (4, 6,  N'Kadın Ayakkabı'),
    (4, 7,  N'Çanta'),                 (4, 8,  N'Aksesuar'),
    (4, 9,  N'İç Giyim'),

    -- Ev (alt)
    (5, 1,  N'Mutfak'),                (5, 2,  N'Banyo'),
    (5, 3,  N'Yatak Odası'),           (5, 4,  N'Salon'),
    (5, 5,  N'Aydınlatma'),            (5, 6,  N'Tekstil'),
    (5, 7,  N'Dekorasyon'),            (5, 8,  N'Beyaz Eşya'),
    (5, 9,  N'Bahçe'),

    -- Hobi (alt)
    (6, 1,  N'Resim'),                 (6, 2,  N'Müzik'),
    (6, 3,  N'Spor'),                  (6, 4,  N'Outdoor'),
    (6, 5,  N'Oyun'),                  (6, 6,  N'El Sanatları'),
    (6, 7,  N'Koleksiyon'),            (6, 8,  N'Bisiklet'),
    (6, 9,  N'Bahçe'),

    -- Yeni ana kategoriler (7-10) ve alt'ları:

    -- Kozmetik
    (7, 1,  N'Cilt Bakım'),            (7, 2,  N'Saç Bakım'),
    (7, 3,  N'Makyaj'),                (7, 4,  N'Parfüm'),
    (7, 5,  N'Erkek Bakım'),           (7, 6,  N'Doğal Kozmetik'),
    (7, 7,  N'Manikür'),               (7, 8,  N'Banyo Ürünleri'),
    (7, 9,  N'Güneş Koruma'),          (7, 10, N'Bebek Bakım'),

    -- Anne-Bebek
    (8, 1,  N'Bebek Giyim'),           (8, 2,  N'Bebek Bakım'),
    (8, 3,  N'Mama'),                  (8, 4,  N'Oyuncak'),
    (8, 5,  N'Bebek Arabası'),         (8, 6,  N'Bebek Odası'),
    (8, 7,  N'Hamile Giyim'),          (8, 8,  N'Bebek Beslenme'),
    (8, 9,  N'Eğitici Oyun'),          (8, 10, N'Banyo Ürünü'),

    -- Pet Shop
    (9, 1,  N'Kedi Maması'),           (9, 2,  N'Köpek Maması'),
    (9, 3,  N'Akvaryum'),              (9, 4,  N'Kuş'),
    (9, 5,  N'Pet Oyuncak'),           (9, 6,  N'Pet Bakım'),
    (9, 7,  N'Pet Aksesuar'),          (9, 8,  N'Pet Sağlık'),
    (9, 9,  N'Pet Yatak'),             (9, 10, N'Tasma ve Kayış'),

    -- Otomotiv
    (10, 1, N'İç Aksesuar'),           (10, 2, N'Dış Aksesuar'),
    (10, 3, N'Ses Sistemi'),           (10, 4, N'Bakım'),
    (10, 5, N'Motor Yağı'),            (10, 6, N'Lastik'),
    (10, 7, N'Çocuk Koltuğu'),         (10, 8, N'Kamp Aksesuar'),
    (10, 9, N'Motosiklet'),            (10, 10, N'Aydınlatma')
) AS c(group_no, sub_no, name);

PRINT '> 94 ek kategori eklendi (toplam 100)';

-- ----------------------------------------------------------------------------
-- Şablon sözlükleri — her grup için sıfat, isim, varyant
-- ----------------------------------------------------------------------------

DECLARE @adj TABLE (group_no INT, idx INT, w NVARCHAR(50));
INSERT INTO @adj VALUES
    -- generic adjectives (group_no=0)
    (0,1,N'Premium'),(0,2,N'Klasik'),(0,3,N'Modern'),(0,4,N'Lüks'),(0,5,N'Ekonomik'),
    (0,6,N'Profesyonel'),(0,7,N'Şık'),(0,8,N'Pratik'),(0,9,N'Dayanıklı'),(0,10,N'Hafif'),
    (0,11,N'Kompakt'),(0,12,N'Doğal'),(0,13,N'Organik'),(0,14,N'El Yapımı'),(0,15,N'Sınırlı'),
    (0,16,N'Akıllı'),(0,17,N'Hızlı'),(0,18,N'Sessiz'),(0,19,N'Esnek'),(0,20,N'Konforlu');

DECLARE @variant TABLE (idx INT, w NVARCHAR(40));
INSERT INTO @variant VALUES
    (1,N'S'),(2,N'M'),(3,N'L'),(4,N'XL'),(5,N'XXL'),
    (6,N'Beyaz'),(7,N'Siyah'),(8,N'Gri'),(9,N'Lacivert'),(10,N'Bej'),
    (11,N'Kırmızı'),(12,N'Mavi'),(13,N'Yeşil'),(14,N'Sarı'),(15,N'Pembe'),
    (16,N'Mat'),(17,N'Parlak'),(18,N'Saten'),(19,N'Vintage'),(20,N'Yeni Sezon'),
    (21,N'Aile Boy'),(22,N'Mini'),(23,N'Maxi'),(24,N'Slim'),(25,N'Regular'),
    (26,N'250 ml'),(27,N'500 ml'),(28,N'1 L'),(29,N'250 gr'),(30,N'500 gr'),
    (31,N'1 kg'),(32,N'2 kg'),(33,N'5''li Paket'),(34,N'10''lu Paket'),(35,N'Tekli'),
    (36,N'Pro'),(37,N'Lite'),(38,N'Plus'),(39,N'Ultra'),(40,N'Max');

-- Kategori bazlı ana isim listesi (her grup için)
DECLARE @noun TABLE (group_no INT, idx INT, w NVARCHAR(60), tr_desc NVARCHAR(200), price_min DECIMAL(12,2), price_max DECIMAL(12,2));
INSERT INTO @noun VALUES
    -- Kitap (1)
    (1,1, N'Roman',          N'Çağdaş Türk edebiyatından bir roman.',                       80,   320),
    (1,2, N'Şiir Kitabı',    N'Türkçe seçme şiir antolojisi, ciltli baskı.',                65,   260),
    (1,3, N'Tarih Kitabı',   N'Anadolu tarihi üzerine akademik bir inceleme.',             120,   480),
    (1,4, N'Felsefe Kitabı', N'Batı ve Doğu felsefesinden seçme metinler.',                100,   420),
    (1,5, N'Çocuk Hikayesi', N'5-9 yaş arası için resimli hikaye kitabı.',                  55,   180),
    (1,6, N'Çizgi Roman',    N'Karton kapaklı çizgi roman albümü.',                         85,   320),
    (1,7, N'Yemek Kitabı',   N'Akdeniz mutfağından 80 yemek tarifi.',                      150,   480),
    (1,8, N'Akademik Kitap', N'Üniversite ders kitabı, güncel baskı.',                     250,   850),
    (1,9, N'Atlas',          N'Renkli haritalar ile dünya atlası.',                        180,   620),
    (1,10,N'Sözlük',         N'Açıklamalı genel Türkçe sözlük.',                            95,   320),

    -- Elektronik (2)
    (2,1, N'Klavye',         N'USB-C bağlantılı kablolu mekanik klavye, ergonomik.',       650,  4500),
    (2,2, N'Mouse',          N'Kablosuz ergonomik mouse, 6 buton, 1 yıl pil.',             280,  2200),
    (2,3, N'Monitör',        N'IPS panel masaüstü monitör, geniş renk gamı.',             3800, 22000),
    (2,4, N'Kulaklık',       N'Aktif gürültü engelleyici Bluetooth kulaklık.',            1200,  9800),
    (2,5, N'Tablet',         N'Wi-Fi tablet, parlak ekran, uzun pil.',                    5500, 32000),
    (2,6, N'Telefon',        N'Android akıllı telefon, çift kamera.',                     6500, 48000),
    (2,7, N'Akıllı Saat',    N'Su geçirmez akıllı saat, kalp ritmi.',                     1850,  9800),
    (2,8, N'Hoparlör',       N'Taşınabilir Bluetooth hoparlör, 12 saat pil.',              850,  6500),
    (2,9, N'Yazıcı',         N'Renkli mürekkep püskürtmeli yazıcı, Wi-Fi.',               2200,  8500),
    (2,10,N'Web Kamerası',   N'Full HD web kamerası, otomatik aydınlatma.',                650,  2400),

    -- Gıda (3)
    (3,1, N'Kahve Çekirdeği', N'Tek menşeli kavrulmuş arabica kahve çekirdeği.',           180,   650),
    (3,2, N'Çay',             N'Klasik filiz çay, ilk hasat.',                              85,   320),
    (3,3, N'Çikolata',        N'%70 kakao oranlı bitter çikolata tablet.',                  60,   220),
    (3,4, N'Bal',             N'Doğal çiçek balı, cam kavanoz.',                           220,   850),
    (3,5, N'Zeytinyağı',      N'Erken hasat sızma zeytinyağı, soğuk pres.',                280,   780),
    (3,6, N'Fındık',          N'Karadeniz fındığı, kavrulmuş, premium.',                   320,   850),
    (3,7, N'Pekmez',          N'Geleneksel taş üzüm pekmezi.',                              95,   320),
    (3,8, N'Pul Biber',       N'Maraş usulü kırmızı pul biber.',                            65,   220),
    (3,9, N'Tahin',           N'Stoneground organik tahin, cam kavanoz.',                  120,   380),
    (3,10,N'Reçel',           N'Geleneksel ev yapımı kayısı reçeli.',                       95,   280),

    -- Giyim (4)
    (4,1, N'Gömlek',         N'Pamuklu uzun kollu erkek gömleği, klasik kesim.',          380,  1450),
    (4,2, N'Tişört',         N'Basic pamuklu kısa kollu tişört.',                          120,   480),
    (4,3, N'Kazak',          N'Yün karışımı V yaka kazak, kış sezonu.',                   480,  1850),
    (4,4, N'Pantolon',       N'Slim-fit pamuklu pantolon, beş cep.',                      450,  1650),
    (4,5, N'Kot Pantolon',   N'Streçli denim kot, klasik kesim.',                         480,  1850),
    (4,6, N'Mont',           N'Kapüşonlu su geçirmez kış montu.',                        1450,  4800),
    (4,7, N'Spor Ayakkabı',  N'Hafif nefes alan koşu ayakkabısı.',                        850,  3800),
    (4,8, N'Klasik Ayakkabı', N'Hakiki deri klasik erkek ayakkabı.',                      850,  3500),
    (4,9, N'Çanta',          N'Tuval omuz çantası, su itici.',                            450,  2200),
    (4,10,N'Elbise',         N'Diz altı kadın elbise, ofis için.',                        680,  2800),

    -- Ev (5)
    (5,1, N'Mutfak Robotu',  N'Çok fonksiyonlu mutfak robotu, 1200W.',                   1850,  5800),
    (5,2, N'Tencere Seti',   N'Granit kaplama 7 parça tencere seti.',                    1450,  4800),
    (5,3, N'Havlu Seti',     N'Bambu lifi 4 parça banyo havlu seti.',                     380,  1450),
    (5,4, N'Yatak Örtüsü',   N'Çift kişilik %100 pamuk perküler yatak örtüsü.',           850,  2800),
    (5,5, N'Masa Lambası',   N'Dimer fonksiyonlu LED masa lambası.',                      480,  1850),
    (5,6, N'Halı',           N'El dokuma Anadolu motifli yün halı.',                    2200,  8500),
    (5,7, N'Yastık',         N'Memory foam ortopedik boyun yastığı.',                     380,  1280),
    (5,8, N'Buzdolabı',      N'No-frost çift kapılı buzdolabı, A+++.',                 18000, 48000),
    (5,9, N'Çamaşır Makinesi', N'8 kg çamaşır makinesi, sessiz motor.',                 12000, 32000),
    (5,10,N'Mum',            N'Soya mumu, lavanta aromalı, 40 saat.',                     120,   480),

    -- Hobi (6)
    (6,1, N'Boya Seti',      N'24 renkli akrilik boya seti, tüpler.',                     280,  1450),
    (6,2, N'Gitar',          N'Akustik gitar, sedir göğüs, tatlı tını.',                 2400, 12500),
    (6,3, N'Yoga Matı',      N'TPE 6 mm kalınlık kaymaz yoga matı.',                      380,  1450),
    (6,4, N'Çadır',          N'Su geçirmez 2 kişilik kamp çadırı, hafif.',               2400,  6800),
    (6,5, N'Yapboz',         N'1000 parça doğa manzaralı yapboz, premium.',                180,   680),
    (6,6, N'Satranç',        N'El yapımı ceviz satranç takımı, ahşap kutu.',              480,  2800),
    (6,7, N'Bisiklet',       N'Şehir bisikleti, 21 vites, alüminyum kadro.',             5800, 22000),
    (6,8, N'Olta',           N'Karbon olta seti, makara dahil, başlangıç.',               850,  3200),
    (6,9, N'Bisiklet Kaskı', N'Ventilasyonlu bisiklet kaskı, ayarlı.',                    280,  1450),
    (6,10,N'Trekking Sopa',  N'Karbon fiber teleskopik trekking bastonu.',                280,   980),

    -- Kozmetik (7)
    (7,1, N'Yüz Kremi',      N'Hyaluronik asit içerikli nemlendirici yüz kremi.',         180,   850),
    (7,2, N'Şampuan',        N'Doğal içerikli sülfatsız şampuan.',                         95,   320),
    (7,3, N'Ruj',            N'Mat bitişli uzun ömürlü ruj.',                              85,   380),
    (7,4, N'Parfüm',          N'Çiçeksi notalı kadın parfümü, 50 ml.',                    480,  2400),
    (7,5, N'Tıraş Köpüğü',   N'Hassas ciltler için yatıştırıcı tıraş köpüğü.',             65,   180),
    (7,6, N'Yüz Maskesi',    N'Kil bazlı temizleyici yüz maskesi, 5''li.',                120,   380),
    (7,7, N'Oje',            N'Çabuk kuruyan, parlak bitişli oje, 12 renk.',               45,   180),
    (7,8, N'Duş Jeli',       N'Doğal bademyağlı duş jeli, 500 ml.',                        65,   240),
    (7,9, N'Güneş Kremi',    N'SPF 50+ yüksek koruma güneş kremi.',                       180,   680),
    (7,10,N'Bebek Şampuanı',  N'Göz yakmayan bebek şampuanı, 400 ml.',                     85,   280),

    -- Anne-Bebek (8)
    (8,1, N'Bebek Tulum',    N'%100 pamuk uzun kollu bebek tulumu.',                      180,   620),
    (8,2, N'Mama',           N'1 yaş+ kahvaltılık bebek maması, 250 gr.',                  85,   240),
    (8,3, N'Bebek Bezi',     N'Dermatolojik test edilmiş bebek bezi, 60''lı.',            220,   480),
    (8,4, N'Oyuncak',        N'Yumuşak peluş oyuncak, makinede yıkanır.',                  85,   380),
    (8,5, N'Bebek Arabası',  N'Katlanabilir bebek arabası, çift yön.',                   4800, 12800),
    (8,6, N'Beşik',          N'Sallanabilen ahşap bebek beşiği, doğal.',                 2200,  6800),
    (8,7, N'Hamile Giyim',   N'Esnek bel hamile pantolonu, ofis.',                        480,  1450),
    (8,8, N'Biberon',        N'BPA-içermez 250 ml biberon, doğal akış.',                  120,   320),
    (8,9, N'Eğitici Oyun',   N'Ahşap yapboz, 2 yaş+ eğitici.',                            180,   680),
    (8,10,N'Bebek Banyosu',  N'Termal bebek banyo küveti, kaymaz.',                       380,  1280),

    -- Pet Shop (9)
    (9,1, N'Kedi Maması',    N'Tahılsız kuru kedi maması, 3 kg.',                         320,   880),
    (9,2, N'Köpek Maması',   N'Yetişkin köpek maması, kuzu etli.',                        480,  1850),
    (9,3, N'Akvaryum',       N'30 litre cam akvaryum seti, filtre dahil.',                850,  2400),
    (9,4, N'Kuş Kafesi',     N'Geniş kuş kafesi, taşıma kollu.',                          480,  1450),
    (9,5, N'Pet Oyuncak',    N'Dayanıklı ısırma oyuncağı, doğal kauçuk.',                  85,   280),
    (9,6, N'Pet Şampuan',    N'Hassas ciltli pet şampuanı, 250 ml.',                       95,   280),
    (9,7, N'Tasma',          N'Reflektörlü pet tasma, 1.5 m.',                            120,   380),
    (9,8, N'Pet Yatak',      N'Yıkanabilir kedi-köpek yatağı, orta boy.',                  280,   980),
    (9,9, N'Kum Kabı',       N'Otomatik kapaklı kedi kum kabı.',                          380,   980),
    (9,10,N'Vitamin',        N'Pet için multi-vitamin damla, 30 ml.',                     180,   480),

    -- Otomotiv (10)
    (10,1, N'Araç Şarj Aleti', N'Hızlı şarj USB-C araç şarj aleti, 65W.',                  220,   620),
    (10,2, N'Telefon Tutucu',  N'Magnetik araç telefon tutucusu, döner.',                  120,   380),
    (10,3, N'Araç Hoparlör',   N'Bluetooth araç hoparlörü, eller serbest.',                280,   980),
    (10,4, N'Cam Suyu',        N'Konsantre cam suyu, kış formülü, 4 lt.',                   45,   180),
    (10,5, N'Motor Yağı',      N'Tam sentetik motor yağı, 4 lt.',                          680,  1850),
    (10,6, N'Lastik',          N'Yaz lastiği, 195/65 R15.',                              2800,  6800),
    (10,7, N'Çocuk Koltuğu',   N'9-36 kg yaş grubu araç çocuk koltuğu.',                 2200,  5800),
    (10,8, N'Kamp Sandalyesi', N'Katlanır kamp sandalyesi, taşıma çantalı.',               280,   780),
    (10,9, N'Motosiklet Eldiveni', N'Deri motosiklet eldiveni, koruma takviyeli.',         480,  1450),
    (10,10,N'LED Far',          N'H7 LED far ampulü, 6000K beyaz.',                        380,   980);

-- ----------------------------------------------------------------------------
-- 50.000 ürün üretimi
-- ----------------------------------------------------------------------------

-- Yapı: 100 kategori × ortalama 500 ürün = 50.000
-- Her kategori için: tüm sıfat × ad × varyant = 20×10×40 = 8000 (çok fazla)
-- 500 ürün/kategori için sample: ROW_NUMBER MOD ile filtrele.

WITH all_cats AS (
    SELECT c.category_id,
           CASE
               WHEN c.category_id BETWEEN 1 AND 6 THEN c.category_id
               WHEN c.category_id BETWEEN 7  AND 15 THEN 1
               WHEN c.category_id BETWEEN 16 AND 26 THEN 2
               WHEN c.category_id BETWEEN 27 AND 36 THEN 3
               WHEN c.category_id BETWEEN 37 AND 46 THEN 4
               WHEN c.category_id BETWEEN 47 AND 56 THEN 5
               WHEN c.category_id BETWEEN 57 AND 65 THEN 6
               WHEN c.category_id BETWEEN 66 AND 75 THEN 7
               WHEN c.category_id BETWEEN 76 AND 85 THEN 8
               WHEN c.category_id BETWEEN 86 AND 95 THEN 9
               WHEN c.category_id BETWEEN 96 AND 100 THEN 10
               ELSE 1
           END AS group_no,
           c.name AS cat_name
    FROM   shop.product_category c
    WHERE  c.category_id <= 100
),
generator AS (
    SELECT
        c.category_id, c.group_no, c.cat_name,
        n.idx AS noun_idx, n.w AS noun, n.tr_desc, n.price_min, n.price_max,
        a.idx AS adj_idx,  a.w AS adj,
        v.idx AS var_idx,  v.w AS variant,
        ROW_NUMBER() OVER (PARTITION BY c.category_id ORDER BY n.idx, a.idx, v.idx) AS rn
    FROM all_cats c
    CROSS APPLY (SELECT TOP 5 * FROM @noun WHERE group_no = c.group_no ORDER BY idx) n
    CROSS JOIN (SELECT TOP 10 * FROM @adj WHERE group_no = 0  ORDER BY idx) a
    CROSS JOIN (SELECT TOP 10 * FROM @variant ORDER BY idx) v
)
INSERT INTO shop.product (product_id, sku, name, category_id, price, description_tr, description_en, is_active, created_at)
SELECT
    1120 + ROW_NUMBER() OVER (ORDER BY category_id, rn) AS product_id,
    'GEN-' + RIGHT('00000' + CAST(1120 + ROW_NUMBER() OVER (ORDER BY category_id, rn) AS VARCHAR(10)), 5) AS sku,
    LEFT(adj + N' ' + noun + N' ' + variant, 200) AS name,
    category_id,
    -- Fiyat: kategori range içinde, varyant idx ile salınımlı
    CAST(price_min + (price_max - price_min) * (((adj_idx * 7 + var_idx * 13) % 100) / 100.0) AS DECIMAL(12, 2)) AS price,
    -- description_tr: cat baz + sıfat + varyant detayı
    LEFT(adj + N' kalitede ' + LOWER(noun) + N' (' + variant + N'). ' + tr_desc, 400) AS description_tr,
    NULL AS description_en,
    1 AS is_active,
    DATEADD(MINUTE, (category_id * 137 + rn * 17) % (365 * 24 * 60), '2026-01-01') AS created_at
FROM generator
WHERE rn <= 500;   -- her kategoriden en fazla 500 ürün

PRINT '> Yeni ürünler eklendi';

SELECT entity = 'product (total)', n = COUNT(*) FROM shop.product
UNION ALL
SELECT 'product (new)',  COUNT(*) FROM shop.product WHERE product_id > 1120
UNION ALL
SELECT 'product_category', COUNT(*) FROM shop.product_category;
GO
