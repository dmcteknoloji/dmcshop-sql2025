-- ============================================================================
-- 05-seed-shop.sql
-- shop.* tablolarına deterministik seed verisi.
-- 6 kategori, 120 ürün, 50 müşteri, 80 device, 400 sipariş, ~1000 satır.
-- Tüm ID'ler sabit (IDENTITY_INSERT ON) — embedding JSONL'larıyla eşleşme şart.
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

DECLARE @baseline DATETIME2 = '2026-01-01';

-- ----------------------------------------------------------------------------
-- Kategoriler
-- ----------------------------------------------------------------------------
INSERT INTO shop.product_category (category_id, name, parent_category_id, created_at) VALUES
    (1, N'Kitap',      NULL, @baseline),
    (2, N'Elektronik', NULL, @baseline),
    (3, N'Gıda',       NULL, @baseline),
    (4, N'Giyim',      NULL, @baseline),
    (5, N'Ev',         NULL, @baseline),
    (6, N'Hobi',       NULL, @baseline);

-- ----------------------------------------------------------------------------
-- Ürünler — 6 kategori × 20 ürün = 120 ürün
-- Her kategoride 10 showcase (elle yazılı, semantic search için kritik) +
-- 10 template-driven varyasyon (alt-tip mantığıyla).
-- ----------------------------------------------------------------------------

-- Kategori 1: Kitap (1001-1020)
INSERT INTO shop.product (product_id, sku, name, category_id, price, description_tr, description_en) VALUES
    (1001, 'BK-001', N'Sıfırdan Bire',                  1,  185.00, N'Peter Thiel''den girişimcilik klasiği. Sıfırdan değer yaratan şirketlerin nasıl kurulduğunu anlatır.',                     N'Zero to One by Peter Thiel — classic entrepreneurship book on building zero-to-one companies.'),
    (1002, 'BK-002', N'Yaratıcılar Yarışı',             1,  220.00, N'Walter Isaacson''dan Steve Jobs, Einstein ve Da Vinci biyografileri ışığında yaratıcılığın anatomisi.',                  N'The Innovators by Walter Isaacson — biographies of creators and innovators.'),
    (1003, 'BK-003', N'Düşünme: Hızlı ve Yavaş',        1,  240.00, N'Daniel Kahneman''ın bilişsel önyargılar üzerine çalışması; karar verme süreçlerinde iki sistem teorisi.',                N'Thinking, Fast and Slow by Daniel Kahneman — cognitive biases and decision making.'),
    (1004, 'BK-004', N'Tutkulu Beyin',                  1,  175.00, N'Antonio Damasio''nun duygu ve bilinç üzerine nörobilim incelemesi.',                                                     N'The Feeling of What Happens by Antonio Damasio — neuroscience of emotion and consciousness.'),
    (1005, 'BK-005', N'Veri Madenciliği El Kitabı',     1,  340.00, N'Veri bilimi pratiği için T-SQL, Python ve istatistik temelli pratik bir rehber. Vaka çalışmalarıyla.',                   N'Data Mining Handbook — practical guide combining T-SQL, Python and statistics with case studies.'),
    (1006, 'BK-006', N'SQL Performans Sırları',         1,  280.00, N'İndeks tasarımı, execution plan okuma ve sorgu optimizasyonu üzerine deneyimli DBA''lara yönelik ileri seviye kitap.',   N'SQL Performance Secrets — advanced indexing and query optimization for DBAs.'),
    (1007, 'BK-007', N'Mimari Desenler',                1,  310.00, N'Mikroservis, event sourcing, CQRS ve domain-driven design pratiklerinin gerçek dünya örnekleriyle anlatımı.',           N'Architecture Patterns — microservices, event sourcing, CQRS, DDD with real-world examples.'),
    (1008, 'BK-008', N'Stoacı Filozof',                 1,  150.00, N'Marcus Aurelius''un Düşünceler''i — modern Türkçe çeviri ve detaylı bağlam notlarıyla.',                                 N'The Stoic Philosopher — Marcus Aurelius Meditations in modern Turkish translation.'),
    (1009, 'BK-009', N'Klasik Yemek Tarifleri',         1,  195.00, N'Anadolu mutfağından klasik yemek tarifleri; geleneksel pişirme teknikleri ve mevsimsel malzemeler.',                    N'Classic Recipes — Anatolian cuisine with traditional cooking techniques.'),
    (1010, 'BK-010', N'Şiir Antolojisi',                1,  140.00, N'Cumhuriyet dönemi Türk şiirinden seçkiler; Nazım Hikmet''ten İlhan Berk''e modern Türk şiirinin örnekleri.',              N'Poetry Anthology — modern Turkish poetry from Nazım Hikmet to İlhan Berk.'),
    (1011, 'BK-011', N'Roman Klasikleri Seti',          1,  450.00, N'Türk ve dünya edebiyatı klasiklerinden 5 kitaplık özel set; ciltli baskı.',                                              N'Classic Novels Set — 5-book hardcover set of Turkish and world literature.'),
    (1012, 'BK-012', N'Çocuk Masalları',                1,  120.00, N'Eski Türk masallarından derleme; ilkokul çağı için renkli illüstrasyonlu çocuk kitabı.',                                 N'Children Tales — illustrated Turkish folk tales for elementary age.'),
    (1013, 'BK-013', N'Tarih Atlası',                   1,  385.00, N'Osmanlı''dan Cumhuriyet''e Anadolu tarihinin görsel atlası; haritalar ve dönem fotoğraflarıyla.',                        N'Historical Atlas — visual history of Anatolia with maps and period photographs.'),
    (1014, 'BK-014', N'Bilim Kurgu Dergisi',            1,   85.00, N'Aylık bilim kurgu dergisi; öykü, roman tefrikası ve bilim makaleleri.',                                                  N'Science Fiction Magazine — monthly fiction and science articles.'),
    (1015, 'BK-015', N'Yoga Felsefesi',                 1,  165.00, N'Sutralar ve modern yorum; günlük yoga pratiği için felsefe temelli bir rehber.',                                         N'Yoga Philosophy — sutras with modern interpretation as a daily practice guide.'),
    (1016, 'BK-016', N'Sanat Tarihi Kompendyumu',       1,  420.00, N'Rönesans''tan 21. yüzyıl çağdaş sanatına; akımlar, ressamlar ve eserlerin kronolojik incelemesi.',                       N'Art History Compendium — from Renaissance to 21st century contemporary art.'),
    (1017, 'BK-017', N'Felsefe Sözlüğü',                1,  295.00, N'Antik Yunan''dan modern felsefeye 800 kavram; ansiklopedik referans.',                                                   N'Philosophy Dictionary — 800 concepts from ancient Greek to modern philosophy.'),
    (1018, 'BK-018', N'Coğrafya Atlası',                1,  175.00, N'Dünya fiziki ve siyasi haritalar; iklim, nüfus ve ekonomi verileriyle güncel atlas.',                                    N'Geography Atlas — physical and political world maps with climate and economic data.'),
    (1019, 'BK-019', N'Doğa Fotoğrafları',              1,  365.00, N'Türkiye''nin doğal güzelliklerinden seçilmiş fotoğraflar; büyük boy ciltli koleksiyon kitabı.',                            N'Nature Photography — large format collection of Turkey natural beauties.'),
    (1020, 'BK-020', N'Müzik Teorisi',                  1,  230.00, N'Nota, akor, ritim ve armoni temelleri; piyano ve gitar için pratik egzersizlerle.',                                      N'Music Theory — fundamentals with practical exercises for piano and guitar.');

-- Kategori 2: Elektronik (1021-1040)
INSERT INTO shop.product (product_id, sku, name, category_id, price, description_tr, description_en) VALUES
    (1021, 'EL-001', N'Mekanik Klavye Cherry MX Brown', 2, 2450.00, N'104 tuşlu, Cherry MX Brown switch''li, RGB aydınlatmalı mekanik klavye. Uzun yazı seanslarında parmaklarınızı yormaz, sessiz tıklama hissi verir.', N'Mechanical keyboard with Cherry MX Brown switches, RGB backlight, ergonomic for long typing sessions.'),
    (1022, 'EL-002', N'Logitech MX Master 3S',          2, 3200.00, N'Kablosuz ergonomik mouse; 8000 DPI sensör, sessiz tık, 70 günlük şarj. Uzun süre kullanımda bilek yormaz.',                N'Wireless ergonomic mouse, 8000 DPI, silent click, 70-day battery — easy on wrist for long use.'),
    (1023, 'EL-003', N'Apple Studio Display 27"',       2,52000.00, N'27 inç 5K Retina ekran; entegre webcam ve hoparlör. Mac Studio ve MacBook Pro için ideal yan ekran.',                     N'27-inch 5K Retina display with integrated webcam and speakers — ideal companion for Mac.'),
    (1024, 'EL-004', N'Sony WH-1000XM5 Kulaklık',       2, 9800.00, N'Aktif gürültü engelleyici, 30 saat pil ömürlü kablosuz kulaklık. Uçak ve ofiste rahat ses deneyimi.',                   N'Wireless noise-cancelling headphones, 30-hour battery — comfortable for flights and office.'),
    (1025, 'EL-005', N'Anker GaN 100W Şarj Cihazı',     2,  890.00, N'4 portlu, 100W GaN teknolojili hızlı şarj cihazı. Laptop, telefon ve tablet aynı anda şarj eder.',                       N'4-port 100W GaN fast charger — simultaneous laptop, phone and tablet charging.'),
    (1026, 'EL-006', N'Samsung T7 SSD 1TB',             2, 1850.00, N'USB-C 3.2 Gen 2, 1050 MB/s okuma; cep boyutunda taşınabilir SSD. Video düzenleme için ideal.',                            N'USB-C portable SSD 1TB, 1050 MB/s read — ideal for video editing.'),
    (1027, 'EL-007', N'iPad Air M3',                    2,28500.00, N'10.9 inç Liquid Retina ekranlı tablet; M3 çip, Apple Pencil destekli. Çizim ve not için ideal.',                          N'iPad Air with M3 chip, 10.9" Liquid Retina, Apple Pencil compatible — ideal for drawing and notes.'),
    (1028, 'EL-008', N'Kindle Paperwhite',              2, 4200.00, N'6.8 inç e-mürekkep ekran, su geçirmez, ayarlanabilir sıcak ışık. Uzun okuma seansları için göz yormaz.',                  N'6.8" e-ink reader, waterproof, adjustable warm light — easy on eyes for long reading.'),
    (1029, 'EL-009', N'Bose SoundLink Mini',            2, 3650.00, N'Taşınabilir bluetooth hoparlör; 12 saat pil, ev ve dış mekan için dengeli ses.',                                          N'Portable bluetooth speaker, 12-hour battery — balanced sound for home and outdoor.'),
    (1030, 'EL-010', N'GoPro Hero 12',                  2,15800.00, N'5.3K video çekim, HyperSmooth stabilizasyon, su geçirmez aksiyon kamerası.',                                              N'5.3K action camera with HyperSmooth stabilization, waterproof.'),
    (1031, 'EL-011', N'Asus ROG Monitor 32"',           2,18900.00, N'32 inç 4K 144Hz oyun monitörü; HDR, G-Sync uyumlu.',                                                                       N'32" 4K 144Hz gaming monitor with HDR and G-Sync.'),
    (1032, 'EL-012', N'Mouse Pad XL Deri',              2,  350.00, N'90x40 cm büyük boy deri mouse pad; klavye ve mouse için tek alan.',                                                       N'90x40cm leather mousepad — single surface for keyboard and mouse.'),
    (1033, 'EL-013', N'USB-C Hub 7-in-1',               2,  720.00, N'HDMI, 2x USB-A, USB-C PD, SD/microSD, Ethernet portlu hub.',                                                              N'7-in-1 USB-C hub with HDMI, USB-A, PD, SD/microSD, Ethernet.'),
    (1034, 'EL-014', N'Webcam Logitech C920',           2, 1450.00, N'Full HD 1080p webcam; otomatik aydınlatma düzeltme, çift mikrofon.',                                                      N'Full HD 1080p webcam with auto light correction and dual microphone.'),
    (1035, 'EL-015', N'Akıllı Saat Garmin Fenix 7',     2,21500.00, N'GPS, kalp ritmi, SpO2, 18 günlük pil; outdoor sporcular için tasarlandı.',                                                 N'GPS smartwatch with heart rate, SpO2, 18-day battery — designed for outdoor athletes.'),
    (1036, 'EL-016', N'Drone DJI Mini 4 Pro',           2,28000.00, N'249g taşınabilir drone; 4K HDR video, 34 dakika uçuş süresi.',                                                            N'249g portable drone with 4K HDR video and 34-minute flight time.'),
    (1037, 'EL-017', N'Mikrofon Shure MV7',             2, 8200.00, N'XLR/USB dual çıkışlı dynamic podcast mikrofonu; gürültü reddi yüksek.',                                                    N'XLR/USB dynamic podcast microphone with high noise rejection.'),
    (1038, 'EL-018', N'Raspberry Pi 5 8GB',             2, 1650.00, N'8GB RAM''li tek kart bilgisayar; ev otomasyonu ve eğitim projeleri için.',                                                  N'Single-board computer with 8GB RAM — for home automation and education projects.'),
    (1039, 'EL-019', N'NAS Synology DS224+',            2,18500.00, N'2 disk yuvalı ev/ofis NAS; medya sunucu, yedekleme ve dosya paylaşım.',                                                   N'2-bay NAS for home/office — media server, backup, file sharing.'),
    (1040, 'EL-020', N'E-Kitap Okuyucu Kobo Libra',     2, 5200.00, N'7 inç e-mürekkep, fiziksel sayfa butonları; OverDrive kütüphane desteği.',                                                 N'7" e-ink reader with physical page buttons — OverDrive library support.');

-- Kategori 3: Gıda (1041-1060)
INSERT INTO shop.product (product_id, sku, name, category_id, price, description_tr, description_en) VALUES
    (1041, 'GD-001', N'Single Origin Etiyopya Kahve',   3,  385.00, N'Yirgacheffe bölgesinden tek menşeli arabica çekirdek; çiçeksi aroma, hafif asitlik, jasmin notaları.',                    N'Single origin Ethiopia Yirgacheffe arabica beans — floral aroma, mild acidity, jasmine notes.'),
    (1042, 'GD-002', N'Türk Çayı Rize Filiz',           3,  120.00, N'Rize Çayeli bölgesinden ilk hasat filiz çay; demlikten uzun süre rengini koruyan klasik Türk çayı.',                       N'Rize first-flush Turkish tea — classic brew, holds color long in the teapot.'),
    (1043, 'GD-003', N'Bitter Çikolata %85',            3,  165.00, N'Ekvador kakaosundan %85 kakao oranlı bitter çikolata; kahve eşliğinde ideal.',                                            N'Ecuador 85%% dark chocolate — ideal with coffee.'),
    (1044, 'GD-004', N'Bal Anzer Çiçek',                3,  680.00, N'Rize Anzer yaylasından çiçek balı; 500g cam kavanoz, ilkbahar hasatı.',                                                   N'Anzer wildflower honey from Rize — 500g glass jar, spring harvest.'),
    (1045, 'GD-005', N'Sızma Zeytinyağı Ayvalık',       3,  450.00, N'Ayvalık erken hasat sızma zeytinyağı; düşük asitlik, baharatlı meyvemsi tat.',                                            N'Ayvalık early harvest extra virgin olive oil — low acidity, spicy fruity taste.'),
    (1046, 'GD-006', N'Antep Fıstık Çekirdek',          3,  720.00, N'Gaziantep''ten kavrulmamış çiğ Antep fıstığı; baklava ve tatlı yapımı için.',                                              N'Raw Gaziantep pistachios — for baklava and dessert preparation.'),
    (1047, 'GD-007', N'Lokum Karışık Kutu',             3,  285.00, N'Klasik gül, fıstıklı, fındıklı lokum 1 kg karışık kutu; geleneksel İstanbul reçetesi.',                                  N'Mixed Turkish delight 1kg box — rose, pistachio, hazelnut — traditional Istanbul recipe.'),
    (1048, 'GD-008', N'Doğal Mineral Su 12''li',        3,   85.00, N'Cam şişede 12''li doğal mineral su; alkali pH, kalsiyum ve magnezyum açısından zengin.',                                    N'Natural mineral water 12-pack in glass — alkaline pH, calcium and magnesium rich.'),
    (1049, 'GD-009', N'Reishi Mantar Tozu',             3,  550.00, N'Organik reishi (lingzhi) mantar tozu; sıcak içecek ve smoothie için 100g.',                                              N'Organic reishi (lingzhi) mushroom powder 100g — for hot drinks and smoothies.'),
    (1050, 'GD-010', N'Matcha Çay Tozu',                3,  680.00, N'Japonya Uji bölgesinden ceremonial grade matcha; 30g kalay kutu.',                                                       N'Ceremonial grade Uji matcha 30g tin from Japan.'),
    (1051, 'GD-011', N'Granola Karışım 1kg',            3,  185.00, N'Yulaf, badem, kakao tanesi ve goji berili ev yapımı granola.',                                                            N'Homemade granola with oats, almonds, cacao nibs and goji berries.'),
    (1052, 'GD-012', N'Quinoa Üçlü Karışım',            3,  220.00, N'Beyaz, kırmızı ve siyah quinoa karışımı; organik 500g.',                                                                  N'Tri-color quinoa blend — white, red, black — organic 500g.'),
    (1053, 'GD-013', N'Hindistan Cevizi Yağı',          3,  165.00, N'Soğuk pres bakire hindistan cevizi yağı 500ml; yemek pişirme ve cilt bakımı için.',                                       N'Cold-pressed virgin coconut oil 500ml — for cooking and skincare.'),
    (1054, 'GD-014', N'Apple Cider Vinegar',            3,  140.00, N'Filtrelenmemiş elma sirkesi; ham, organik 1L.',                                                                          N'Unfiltered raw organic apple cider vinegar 1L.'),
    (1055, 'GD-015', N'Kuru Mantar Karışımı',           3,  340.00, N'Porcini, shiitake ve istiridye mantarı kuru karışımı; risotto ve makarna için 100g.',                                     N'Dried mushroom mix — porcini, shiitake, oyster — 100g for risotto and pasta.'),
    (1056, 'GD-016', N'Tahin Susam Ezmesi',             3,  175.00, N'Stoneground organik tahin; tatlı ve sos için 500g cam kavanoz.',                                                          N'Stoneground organic tahini 500g — for desserts and sauces.'),
    (1057, 'GD-017', N'Pekmez Üzüm Geleneksel',         3,  220.00, N'Geleneksel taş üzüm pekmezi; kahvaltı ve tahin-pekmez için 500g.',                                                       N'Traditional stone-pressed grape molasses 500g — for breakfast and tahini-molasses.'),
    (1058, 'GD-018', N'Pul Biber Maraş',                3,  120.00, N'Kahramanmaraş usulü kırmızı pul biber; orta acılıkta 250g.',                                                              N'Maraş-style red pepper flakes — medium heat 250g.'),
    (1059, 'GD-019', N'Tuz Çankırı Kayasıdağı',         3,   95.00, N'Çankırı tuz dağından çıkarılan iri taneli doğal kaya tuzu; 1kg.',                                                         N'Coarse natural rock salt from Çankırı salt mountain — 1kg.'),
    (1060, 'GD-020', N'Vanilya Çubuk Madagaskar',       3,  450.00, N'Madagaskar bourbon vanilya çubukları; pastacılık için 5''li paket.',                                                       N'Madagascar bourbon vanilla beans — 5-pack for baking.');

-- Kategori 4: Giyim (1061-1080)
INSERT INTO shop.product (product_id, sku, name, category_id, price, description_tr, description_en) VALUES
    (1061, 'GY-001', N'Slim-Fit Pamuklu Beyaz Gömlek',  4,  650.00, N'%100 pamuk, slim-fit kesim, beyaz uzun kollu erkek gömleği; ofis ve şık giyim için.',                                     N'100%% cotton slim-fit white long-sleeve men shirt — for office and smart attire.'),
    (1062, 'GY-002', N'Yün Kazak Antrasit',             4,  890.00, N'%70 yün karışımı V yaka erkek kazak; antrasit gri, kış için sıcak ve yumuşak.',                                            N'70%% wool V-neck men sweater in anthracite gray — warm and soft for winter.'),
    (1063, 'GY-003', N'Klasik Kot Pantolon Slim',       4,  720.00, N'Streçli pamuk denim, slim-fit erkek kot pantolon; lacivert.',                                                              N'Stretch cotton denim slim-fit men jeans in indigo.'),
    (1064, 'GY-004', N'Yağmurluk Su Geçirmez',          4, 1850.00, N'Gore-Tex teknolojili, su geçirmez nefes alabilen erkek yağmurluk; outdoor için.',                                          N'Gore-Tex waterproof breathable men raincoat — for outdoor use.'),
    (1065, 'GY-005', N'Spor Ayakkabı Hafif',            4, 1450.00, N'Koşu için ergonomik tasarımlı, nefes alan ağ örgülü hafif spor ayakkabı.',                                                 N'Lightweight ergonomic mesh running sneakers — breathable for jogging.'),
    (1066, 'GY-006', N'Pamuklu Tişört 5''li Paket',     4,  580.00, N'Erkek pamuklu basic tişört; siyah, beyaz, gri renklerde 5''li paket.',                                                    N'Men cotton basic t-shirts — 5-pack in black, white, gray.'),
    (1067, 'GY-007', N'Deri Cüzdan',                    4,  680.00, N'%100 hakiki deri ince erkek cüzdanı; RFID korumalı, 8 kart bölmesi.',                                                     N'Genuine leather slim men wallet — RFID protected, 8 card slots.'),
    (1068, 'GY-008', N'Yün Atkı El Dokuması',           4,  450.00, N'Anadolu desenleri ile el dokuması %100 yün atkı; nötr renk paleti.',                                                       N'Handwoven 100%% wool scarf with Anatolian patterns — neutral color palette.'),
    (1069, 'GY-009', N'Sırt Çantası Laptop 16"',        4, 1250.00, N'Su itici kumaş, 16 inç laptop bölmesi, USB şarj portu; iş ve seyahat için.',                                              N'Water-repellent backpack with 16" laptop compartment and USB charging port — for work and travel.'),
    (1070, 'GY-010', N'Kadın Yün Elbise',               4, 1150.00, N'Diz altı uzunluk, %80 yün karışımı kadın elbise; ofis ve günlük şık.',                                                    N'Knee-length 80%% wool women dress — for office and smart casual.'),
    (1071, 'GY-011', N'Spor Tayt Yüksek Bel',           4,  580.00, N'Esnek, hareket özgürlüğü sağlayan yüksek bel kadın spor taytı.',                                                           N'High-waist women sports tights — stretchy with freedom of movement.'),
    (1072, 'GY-012', N'Kazak Yün Boğazlı',              4,  920.00, N'Boğazlı yün kazak; klasik kesim, soğuk kış günleri için yumuşak ve sıcak.',                                                N'Turtleneck wool sweater — classic cut, soft and warm for cold winter days.'),
    (1073, 'GY-013', N'Şort Pamuklu Yaz',               4,  385.00, N'Pamuklu hafif yaz şortu; gevşek kesim, cep detaylı.',                                                                     N'Cotton lightweight summer shorts — loose fit with pocket detail.'),
    (1074, 'GY-014', N'Yün Çorap 5''li',                4,  280.00, N'Merino yün karışımı klasik çorap 5''li paket; lacivert, gri ve siyah.',                                                   N'Merino wool blend classic socks 5-pack — navy, gray and black.'),
    (1075, 'GY-015', N'Şapka Fötr Klasik',              4,  650.00, N'Yün fötr şapka; klasik kesim, sonbahar ve kış için.',                                                                     N'Classic wool felt fedora hat — for fall and winter.'),
    (1076, 'GY-016', N'Eldiven Deri Kürk İçli',         4,  720.00, N'Hakiki deri, suni kürk astarlı kış eldiveni; dokunmatik ekran uyumlu.',                                                    N'Genuine leather faux-fur lined winter gloves — touchscreen compatible.'),
    (1077, 'GY-017', N'Trenchcoat Bej',                 4, 2450.00, N'Klasik bej trench mont; çift sıra düğme, kemer kuşak detaylı.',                                                            N'Classic beige trench coat — double-breasted with belted waist.'),
    (1078, 'GY-018', N'Mocassin Süet',                  4, 1280.00, N'Süet erkek mocassin; rahat kalıp, ofis ve günlük giyim için.',                                                            N'Suede men moccasins — comfortable fit for office and casual.'),
    (1079, 'GY-019', N'Kayak Mont Termal',              4, 3850.00, N'Termal yalıtım, su geçirmez kayak ve snowboard montu; -20°C''ye dayanıklı.',                                              N'Thermal insulated waterproof ski and snowboard jacket — rated to -20°C.'),
    (1080, 'GY-020', N'Pijama Takımı Pamuklu',          4,  580.00, N'%100 pamuk uzun kollu pijama takımı; rahat ev kullanımı için.',                                                          N'100%% cotton long-sleeve pajama set — comfortable for home wear.');

-- Kategori 5: Ev (1081-1100)
INSERT INTO shop.product (product_id, sku, name, category_id, price, description_tr, description_en) VALUES
    (1081, 'EV-001', N'Bambu Mutfak Aleti Seti',        5,  450.00, N'5 parçalı bambu mutfak aleti seti; spatula, kepçe, kaşık, çırpıcı, makarna kepçesi.',                                     N'5-piece bamboo kitchen utensil set — spatula, ladle, spoon, whisk, pasta server.'),
    (1082, 'EV-002', N'Bonsai Saksı Seti',              5,  680.00, N'2''li bonsai saksı seti; toprak, makas ve bakım kılavuzu dahil.',                                                          N'2-piece bonsai pot set with soil, shears and care guide.'),
    (1083, 'EV-003', N'Kahve Demleme French Press',     5,  450.00, N'600ml çift cidarlı camlı French press; sıcaklığı uzun süre korur.',                                                       N'600ml double-walled glass French press — retains heat long.'),
    (1084, 'EV-004', N'Aydınlatma Masa Lambası LED',    5,  920.00, N'Dimer fonksiyonlu, USB şarj portlu masa lambası; göz koruma teknolojili.',                                                 N'Dimmable LED desk lamp with USB charging port — eye care technology.'),
    (1085, 'EV-005', N'Yatak Örtüsü %100 Pamuk',        5, 1250.00, N'Çift kişilik %100 pamuk perküler yatak örtüsü; 240x260cm.',                                                                 N'King-size 100%% cotton percale bedspread — 240x260cm.'),
    (1086, 'EV-006', N'Cam Su Sürahisi Filtreli',       5,  385.00, N'1.5L cam su sürahisi; aktif karbon filtreli, kireç ve klor giderir.',                                                     N'1.5L glass water pitcher with activated carbon filter — removes lime and chlorine.'),
    (1087, 'EV-007', N'Mum Lavanta Aromatik',           5,  220.00, N'Soya mumu, lavanta aromalı; 40 saat yanma süresi, cam kap.',                                                              N'Soy candle with lavender aroma — 40-hour burn, glass jar.'),
    (1088, 'EV-008', N'Havlu Seti Bambu',               5,  680.00, N'4 parçalı bambu lifi banyo havlu seti; yumuşak ve hızlı kuruyan.',                                                       N'4-piece bamboo fiber bath towel set — soft and quick-drying.'),
    (1089, 'EV-009', N'Yemek Takımı Porselen 24''lü',   5, 2850.00, N'24 parçalı porselen yemek takımı; 6 kişilik, klasik beyaz desen.',                                                       N'24-piece porcelain dinnerware — 6 settings, classic white pattern.'),
    (1090, 'EV-010', N'Sandalye Ahşap Sallanır',        5, 3450.00, N'Masif kayın ahşap sallanır sandalye; el yapımı, doğal yağ kaplama.',                                                     N'Solid beech wood rocking chair — handcrafted with natural oil finish.'),
    (1091, 'EV-011', N'Mutfak Bıçağı Çelik',            5, 1850.00, N'Solingen çeliği şef bıçağı 20cm; el dövme tasarım, lifetime garanti.',                                                   N'Solingen steel chef knife 20cm — hand-forged design with lifetime warranty.'),
    (1092, 'EV-012', N'Halı Yün El Dokuma',             5, 4200.00, N'Anadolu motifli el dokuma yün halı; 120x180cm, doğal boyalı.',                                                            N'Handwoven Anatolian wool rug — 120x180cm, naturally dyed.'),
    (1093, 'EV-013', N'Tabak Seramik El Yapımı',        5,  280.00, N'El yapımı seramik servis tabağı; mavi-beyaz Çini motifli, 28cm çap.',                                                     N'Handmade ceramic serving plate — blue-white Çini motifs, 28cm diameter.'),
    (1094, 'EV-014', N'Hava Temizleyici HEPA',          5, 4850.00, N'HEPA H13 filtreli ev tipi hava temizleyici; 50m² oda için ideal.',                                                       N'HEPA H13 home air purifier — ideal for 50m² rooms.'),
    (1095, 'EV-015', N'Yorgan Kaz Tüyü',                5, 3650.00, N'Çift kişilik kaz tüyü yorgan; %90 down doldurma, uzun ömürlü.',                                                          N'Double-size goose down comforter — 90%% down fill, long-lasting.'),
    (1096, 'EV-016', N'Çiçek Saksı Seramik 3''lü',      5,  450.00, N'3 farklı boyutta seramik çiçek saksısı seti; kahverengi mat.',                                                              N'3-piece ceramic flower pot set in different sizes — matte brown.'),
    (1097, 'EV-017', N'Çay Demlik Cam Klasik',          5,  385.00, N'Borosilikat camdan klasik çay demliği; ısıya dayanıklı, 1L kapasiteli.',                                                  N'Classic borosilicate glass teapot — heat resistant, 1L capacity.'),
    (1098, 'EV-018', N'Saat Duvar Klasik',              5,  650.00, N'Sessiz mekanizmalı klasik duvar saati; 35cm çap, ahşap çerçeve.',                                                          N'Silent mechanism classic wall clock — 35cm diameter, wooden frame.'),
    (1099, 'EV-019', N'Yastık Memory Foam',             5,  580.00, N'Boyun destekli memory foam yastık; ortopedik tasarım.',                                                                    N'Memory foam pillow with neck support — orthopedic design.'),
    (1100, 'EV-020', N'Çamaşır Sepeti Bambu',           5,  450.00, N'Bambu çamaşır sepeti; kapaklı, 65L kapasiteli, doğal.',                                                                    N'Bamboo laundry basket with lid — 65L natural capacity.');

-- Kategori 6: Hobi (1101-1120)
INSERT INTO shop.product (product_id, sku, name, category_id, price, description_tr, description_en) VALUES
    (1101, 'HB-001', N'Akrilik Boya Set 24 Renk',       6,  385.00, N'24 renkli akrilik boya seti; ressam ve hobi resmi için, tüplerde 22ml.',                                                  N'24-color acrylic paint set — for painters and hobbyists, 22ml tubes.'),
    (1102, 'HB-002', N'Akustik Gitar Üçgen Pena',       6,   85.00, N'12''li akustik gitar üçgen pena seti; farklı kalınlıklarda.',                                                              N'12-pack acoustic guitar triangle picks — assorted thicknesses.'),
    (1103, 'HB-003', N'Yapboz 1000 Parça',              6,  220.00, N'1000 parça yapboz; doğa manzaralı, premium karton baskı.',                                                                N'1000-piece jigsaw puzzle — nature landscape, premium cardboard print.'),
    (1104, 'HB-004', N'Origami Kağıt Seti',             6,  120.00, N'500 yapraklı origami kağıt seti; 20 renk, 15x15cm.',                                                                       N'500-sheet origami paper set — 20 colors, 15x15cm.'),
    (1105, 'HB-005', N'Dürbün 10x42',                   6, 2850.00, N'10x42 büyütmeli, su geçirmez dürbün; kuş gözlemciliği ve outdoor için.',                                                  N'10x42 magnification waterproof binoculars — for birdwatching and outdoor.'),
    (1106, 'HB-006', N'Dişli Bisiklet Onarım Seti',     6,  450.00, N'Bisiklet onarım için 16 parçalı multitool seti; çelik gövde.',                                                            N'16-piece bicycle repair multitool set with steel body.'),
    (1107, 'HB-007', N'Çadır Kamp 2 Kişilik',           6, 3850.00, N'Su geçirmez 2 kişilik kamp çadırı; 2.4 kg, dakikalar içinde kurulur.',                                                    N'Waterproof 2-person camping tent — 2.4kg, sets up in minutes.'),
    (1108, 'HB-008', N'Akrobat Yoga Matı',              6,  520.00, N'TPE malzeme, 6mm kalınlık, kaymaz yoga matı; siyah-mor desenli.',                                                          N'TPE non-slip yoga mat — 6mm thick, black-purple pattern.'),
    (1109, 'HB-009', N'Resim Tuali Hazır',              6,  380.00, N'40x50cm hazır gerilmiş pamuk resim tuali 3''lü; akrilik ve yağlıboya için.',                                              N'40x50cm pre-stretched cotton canvas 3-pack — for acrylic and oil paint.'),
    (1110, 'HB-010', N'Satranç Takımı Ahşap',           6,  780.00, N'Cevizden el yapımı satranç takımı; 40x40cm tahta, klasik figürler.',                                                      N'Handcrafted walnut chess set — 40x40cm board with classic pieces.'),
    (1111, 'HB-011', N'Kitap Bisiklet Tamiri',          6,  220.00, N'Bisiklet bakım ve tamir rehberi; resimli adım adım anlatım.',                                                              N'Bicycle maintenance and repair guide — illustrated step-by-step.'),
    (1112, 'HB-012', N'Dikiş Makinesi Mini',            6, 1450.00, N'Taşınabilir mini dikiş makinesi; 12 desen, pille çalışır.',                                                                N'Portable mini sewing machine — 12 stitches, battery-powered.'),
    (1113, 'HB-013', N'Sketchbook A4 Hardcover',        6,  185.00, N'A4 sert kapaklı çizim defteri; 160g asitsiz kağıt, 120 sayfa.',                                                            N'A4 hardcover sketchbook — 160gsm acid-free paper, 120 pages.'),
    (1114, 'HB-014', N'Sulu Boya 36 Renk',              6,  450.00, N'Profesyonel sulu boya seti 36 renk; metalik kutu, fırça dahil.',                                                          N'Professional watercolor set 36 colors — metal box with brush.'),
    (1115, 'HB-015', N'Mandala Boyama Kitabı',          6,  120.00, N'Yetişkinler için 50 mandala desenli boyama kitabı; stresi azaltır.',                                                      N'Adult coloring book with 50 mandala designs — stress-reducing.'),
    (1116, 'HB-016', N'Gitar Akort Cihazı',             6,  280.00, N'Klipsli kromatik gitar akort cihazı; LCD ekran, pille çalışır.',                                                          N'Clip-on chromatic guitar tuner — LCD display, battery-powered.'),
    (1117, 'HB-017', N'Lego Mimari Set',                6, 1850.00, N'Lego mimari koleksiyonu Eiffel Kulesi seti; 1500 parça.',                                                                  N'Lego architecture Eiffel Tower set — 1500 pieces.'),
    (1118, 'HB-018', N'Olta Takımı Başlangıç',          6, 1250.00, N'Başlangıç seviyesi olta seti; makara, misina, zoka ve kanca dahil.',                                                      N'Beginner fishing rod set — reel, line, weights and hooks included.'),
    (1119, 'HB-019', N'Trekking Sopa Karbon',           6,  650.00, N'Karbon fiber teleskopik trekking bastonu; titreşim emici tutamak.',                                                       N'Carbon fiber telescopic trekking pole with vibration-absorbing grip.'),
    (1120, 'HB-020', N'Kaykay Cruiser',                 6, 1850.00, N'Cruiser stil kaykay; ahşap güverte, yumuşak tekerlek; şehir için.',                                                       N'Cruiser-style skateboard — wooden deck, soft wheels — for city use.');

PRINT '> 120 ürün eklendi';
GO

-- ----------------------------------------------------------------------------
-- Müşteriler (50 kişi)
-- ----------------------------------------------------------------------------
DECLARE @baseline DATETIME2 = '2026-01-01';

INSERT INTO shop.customer (customer_id, full_name, email, city, created_at) VALUES
    (1, N'Ayşe Yılmaz',      'ayse.yilmaz@example.com',      N'İstanbul', DATEADD(DAY,   0, @baseline)),
    (2, N'Mehmet Demir',     'mehmet.demir@example.com',     N'Ankara',   DATEADD(DAY,   2, @baseline)),
    (3, N'Zeynep Kaya',      'zeynep.kaya@example.com',      N'İzmir',    DATEADD(DAY,   3, @baseline)),
    (4, N'Mustafa Çelik',    'mustafa.celik@example.com',    N'Bursa',    DATEADD(DAY,   5, @baseline)),
    (5, N'Elif Şahin',       'elif.sahin@example.com',       N'Antalya',  DATEADD(DAY,   7, @baseline)),
    (6, N'Ali Doğan',        'ali.dogan@example.com',        N'İstanbul', DATEADD(DAY,   9, @baseline)),
    (7, N'Fatma Aydın',      'fatma.aydin@example.com',      N'İzmir',    DATEADD(DAY,  11, @baseline)),
    (8, N'Hasan Yıldız',     'hasan.yildiz@example.com',     N'Konya',    DATEADD(DAY,  13, @baseline)),
    (9, N'Selin Polat',      'selin.polat@example.com',      N'İstanbul', DATEADD(DAY,  15, @baseline)),
    (10, N'Burak Erdoğan',   'burak.erdogan@example.com',    N'Ankara',   DATEADD(DAY,  17, @baseline)),
    (11, N'Deniz Acar',      'deniz.acar@example.com',       N'İstanbul', DATEADD(DAY,  19, @baseline)),
    (12, N'Canan Öz',        'canan.oz@example.com',         N'İzmir',    DATEADD(DAY,  21, @baseline)),
    (13, N'Emre Çetin',      'emre.cetin@example.com',       N'Bursa',    DATEADD(DAY,  23, @baseline)),
    (14, N'Pınar Koç',       'pinar.koc@example.com',        N'Antalya',  DATEADD(DAY,  25, @baseline)),
    (15, N'Volkan Aksoy',    'volkan.aksoy@example.com',     N'Adana',    DATEADD(DAY,  27, @baseline)),
    (16, N'Gizem Şen',       'gizem.sen@example.com',        N'İstanbul', DATEADD(DAY,  29, @baseline)),
    (17, N'Tuncay Karaca',   'tuncay.karaca@example.com',    N'Ankara',   DATEADD(DAY,  31, @baseline)),
    (18, N'Berna Aslan',     'berna.aslan@example.com',      N'İzmir',    DATEADD(DAY,  33, @baseline)),
    (19, N'Cem Bilgin',      'cem.bilgin@example.com',       N'İstanbul', DATEADD(DAY,  35, @baseline)),
    (20, N'Aslı Güven',      'asli.guven@example.com',       N'Bursa',    DATEADD(DAY,  37, @baseline)),
    (21, N'Onur Kurt',       'onur.kurt@example.com',        N'Trabzon',  DATEADD(DAY,  39, @baseline)),
    (22, N'Sevgi Türk',      'sevgi.turk@example.com',       N'Antalya',  DATEADD(DAY,  41, @baseline)),
    (23, N'Hakan Erdem',     'hakan.erdem@example.com',      N'İstanbul', DATEADD(DAY,  43, @baseline)),
    (24, N'Gül Yiğit',       'gul.yigit@example.com',        N'İzmir',    DATEADD(DAY,  45, @baseline)),
    (25, N'Kerem Sarı',      'kerem.sari@example.com',       N'Ankara',   DATEADD(DAY,  47, @baseline)),
    (26, N'Esra Bozkurt',    'esra.bozkurt@example.com',     N'İstanbul', DATEADD(DAY,  49, @baseline)),
    (27, N'Tolga Yaman',     'tolga.yaman@example.com',      N'Konya',    DATEADD(DAY,  51, @baseline)),
    (28, N'Nazlı Uçar',      'nazli.ucar@example.com',       N'İzmir',    DATEADD(DAY,  53, @baseline)),
    (29, N'Sinan Tan',       'sinan.tan@example.com',        N'Bursa',    DATEADD(DAY,  55, @baseline)),
    (30, N'Melike Doğan',    'melike.dogan@example.com',     N'İstanbul', DATEADD(DAY,  57, @baseline)),
    (31, N'Barış Yılmaz',    'baris.yilmaz@example.com',     N'Ankara',   DATEADD(DAY,  59, @baseline)),
    (32, N'İlayda Kara',     'ilayda.kara@example.com',      N'İstanbul', DATEADD(DAY,  61, @baseline)),
    (33, N'Furkan Akın',     'furkan.akin@example.com',      N'İzmir',    DATEADD(DAY,  63, @baseline)),
    (34, N'Damla Çiftçi',    'damla.ciftci@example.com',     N'Antalya',  DATEADD(DAY,  65, @baseline)),
    (35, N'Yiğit Şahin',     'yigit.sahin@example.com',      N'Adana',    DATEADD(DAY,  67, @baseline)),
    (36, N'Buse Erol',       'buse.erol@example.com',        N'İstanbul', DATEADD(DAY,  69, @baseline)),
    (37, N'Mert Güneş',      'mert.gunes@example.com',       N'Ankara',   DATEADD(DAY,  71, @baseline)),
    (38, N'Sude Çakır',      'sude.cakir@example.com',       N'İzmir',    DATEADD(DAY,  73, @baseline)),
    (39, N'Berkay Polat',    'berkay.polat@example.com',     N'Bursa',    DATEADD(DAY,  75, @baseline)),
    (40, N'Ece Yılmaz',      'ece.yilmaz@example.com',       N'İstanbul', DATEADD(DAY,  77, @baseline)),
    (41, N'Kaan Demirci',    'kaan.demirci@example.com',     N'Trabzon',  DATEADD(DAY,  79, @baseline)),
    (42, N'Defne Akkaya',    'defne.akkaya@example.com',     N'Antalya',  DATEADD(DAY,  81, @baseline)),
    (43, N'Eren Yavuz',      'eren.yavuz@example.com',       N'İstanbul', DATEADD(DAY,  83, @baseline)),
    (44, N'Lale Çevik',      'lale.cevik@example.com',       N'İzmir',    DATEADD(DAY,  85, @baseline)),
    (45, N'Doruk Acar',      'doruk.acar@example.com',       N'Ankara',   DATEADD(DAY,  87, @baseline)),
    (46, N'Beste Önal',      'beste.onal@example.com',       N'İstanbul', DATEADD(DAY,  89, @baseline)),
    (47, N'Arda Şimşek',     'arda.simsek@example.com',      N'Konya',    DATEADD(DAY,  91, @baseline)),
    (48, N'Ada Korkmaz',     'ada.korkmaz@example.com',      N'İzmir',    DATEADD(DAY,  93, @baseline)),
    (49, N'Mete Uğur',       'mete.ugur@example.com',        N'Bursa',    DATEADD(DAY,  95, @baseline)),
    (50, N'İrem Tekin',      'irem.tekin@example.com',       N'İstanbul', DATEADD(DAY,  97, @baseline));

PRINT '> 50 müşteri eklendi';
GO

-- ----------------------------------------------------------------------------
-- Device ve payment_method — fraud senaryolarına temel
-- ----------------------------------------------------------------------------
DECLARE @baseline DATETIME2 = '2026-01-01';

-- 80 device; fraud ring tasarımları:
--   Ring A (3 müşteri / 1 device):  c=2,7,15  → device_id=101
--   Ring B (5 müşteri / 1 IP):      c=10,18,22,30,42  → IP shared via devices 110-114
--   Ring C (2 müşteri / 1 kart):    c=8,33  → card_fingerprint shared (payment_method)
--   Ring D (4 müşteri çapraz):      c=4,12,24,39  → device 130 (3 paylaşır) + payment shared
INSERT INTO shop.device (device_id, fingerprint, ip_address, user_agent, first_seen, last_seen) VALUES
    (101, REPLICATE('a', 64), '192.0.2.101', 'Mozilla/5.0 (Linux x86_64) Chrome/130',          DATEADD(DAY,   5, @baseline), DATEADD(DAY, 100, @baseline)),  -- ring A
    (110, REPLICATE('b', 64), '192.0.2.150', 'Mozilla/5.0 (Windows NT 10.0) Chrome/130',       DATEADD(DAY,  10, @baseline), DATEADD(DAY,  90, @baseline)),  -- ring B
    (111, REPLICATE('c', 64), '192.0.2.150', 'Mozilla/5.0 (Linux x86_64) Firefox/132',         DATEADD(DAY,  12, @baseline), DATEADD(DAY,  92, @baseline)),  -- ring B
    (112, REPLICATE('d', 64), '192.0.2.150', 'Mozilla/5.0 (Macintosh) Safari/17',              DATEADD(DAY,  14, @baseline), DATEADD(DAY,  94, @baseline)),  -- ring B
    (113, REPLICATE('e', 64), '192.0.2.150', 'Mozilla/5.0 (iPhone) Mobile Safari',             DATEADD(DAY,  16, @baseline), DATEADD(DAY,  96, @baseline)),  -- ring B
    (114, REPLICATE('f', 64), '192.0.2.150', 'Mozilla/5.0 (Android 14) Chrome',                DATEADD(DAY,  18, @baseline), DATEADD(DAY,  98, @baseline)),  -- ring B
    (120, REPLICATE('1', 64), '192.0.2.120', 'Mozilla/5.0 (Linux x86_64) Chrome/130',          DATEADD(DAY,  20, @baseline), DATEADD(DAY, 100, @baseline)),  -- ring C device (her müşteri kendi device)
    (121, REPLICATE('2', 64), '192.0.2.121', 'Mozilla/5.0 (Macintosh) Safari/17',              DATEADD(DAY,  22, @baseline), DATEADD(DAY, 102, @baseline)),
    (130, REPLICATE('3', 64), '192.0.2.130', 'Mozilla/5.0 (Windows NT 10.0) Chrome/130',       DATEADD(DAY,  25, @baseline), DATEADD(DAY, 105, @baseline));  -- ring D shared device

-- Kalan 71 normal device (id 200-270): her müşteri için ortalama 1-2 device
DECLARE @i INT = 0;
WHILE @i < 71
BEGIN
    INSERT INTO shop.device (device_id, fingerprint, ip_address, user_agent, first_seen, last_seen)
    VALUES (
        200 + @i,
        RIGHT(REPLICATE('0', 64) + CONVERT(VARCHAR(20), HASHBYTES('SHA1', CAST(200 + @i AS VARCHAR)), 2), 64),
        '203.0.113.' + CAST((@i * 3) % 250 + 1 AS VARCHAR),
        CASE (@i % 4)
            WHEN 0 THEN 'Mozilla/5.0 (Windows NT 10.0) Chrome/130'
            WHEN 1 THEN 'Mozilla/5.0 (Macintosh) Safari/17'
            WHEN 2 THEN 'Mozilla/5.0 (iPhone) Mobile Safari'
            ELSE        'Mozilla/5.0 (Android 14) Chrome'
        END,
        DATEADD(DAY, @i + 5, @baseline),
        DATEADD(DAY, @i + 80, @baseline)
    );
    SET @i = @i + 1;
END

PRINT '> 80 device eklendi';

-- customer_device — fraud ringleri ve normal eşleşmeler
INSERT INTO shop.customer_device (customer_id, device_id, first_seen, last_seen) VALUES
    -- Ring A: 3 müşteri device 101'i paylaşıyor
    ( 2, 101, DATEADD(DAY,  6, @baseline), DATEADD(DAY,  50, @baseline)),
    ( 7, 101, DATEADD(DAY, 12, @baseline), DATEADD(DAY,  60, @baseline)),
    (15, 101, DATEADD(DAY, 28, @baseline), DATEADD(DAY,  80, @baseline)),
    -- Ring B: 5 müşteri farklı device'lar ama hepsi 192.0.2.150 IP
    (10, 110, DATEADD(DAY, 18, @baseline), DATEADD(DAY,  70, @baseline)),
    (18, 111, DATEADD(DAY, 34, @baseline), DATEADD(DAY,  80, @baseline)),
    (22, 112, DATEADD(DAY, 42, @baseline), DATEADD(DAY,  90, @baseline)),
    (30, 113, DATEADD(DAY, 58, @baseline), DATEADD(DAY, 100, @baseline)),
    (42, 114, DATEADD(DAY, 82, @baseline), DATEADD(DAY, 110, @baseline)),
    -- Ring C: device farklı, kart aynı (payment_method'ta kurulacak)
    ( 8, 120, DATEADD(DAY, 14, @baseline), DATEADD(DAY,  70, @baseline)),
    (33, 121, DATEADD(DAY, 64, @baseline), DATEADD(DAY, 110, @baseline)),
    -- Ring D: 3 müşteri device 130 paylaşıyor, 4. müşteri aynı kartı kullanır
    ( 4, 130, DATEADD(DAY, 26, @baseline), DATEADD(DAY,  90, @baseline)),
    (12, 130, DATEADD(DAY, 30, @baseline), DATEADD(DAY,  95, @baseline)),
    (24, 130, DATEADD(DAY, 48, @baseline), DATEADD(DAY, 100, @baseline));
-- Normal müşteri-device eşleşmeleri (kalan 47 müşteri × ortalama 1.4 device)
DECLARE @cust INT = 1;
WHILE @cust <= 50
BEGIN
    IF @cust NOT IN (2, 7, 15, 10, 18, 22, 30, 42, 8, 33, 4, 12, 24)
    BEGIN
        INSERT INTO shop.customer_device (customer_id, device_id, first_seen, last_seen)
        VALUES (
            @cust,
            200 + ((@cust - 1) % 71),
            DATEADD(DAY, @cust * 2, @baseline),
            DATEADD(DAY, @cust * 2 + 60, @baseline)
        );
    END
    SET @cust = @cust + 1;
END

-- Payment methods — 60 kayıt; ring C ve ring D paylaşılan kart
DECLARE @c INT = 1;
DECLARE @pmid BIGINT = 1;
WHILE @c <= 50
BEGIN
    INSERT INTO shop.payment_method (payment_method_id, customer_id, type, last4, card_fingerprint, created_at)
    VALUES (
        @pmid,
        @c,
        'card',
        RIGHT(CAST(1000 + @c AS VARCHAR), 4),
        REPLICATE(CHAR(65 + (@c % 26)), 64),
        DATEADD(DAY, @c, @baseline)
    );
    SET @pmid = @pmid + 1;
    SET @c = @c + 1;
END
-- Ring C: müşteri 8 ve 33 aynı card_fingerprint
UPDATE shop.payment_method SET card_fingerprint = REPLICATE('X', 64) WHERE customer_id IN (8, 33);
-- Ring D: müşteri 39 (device sharing'e dahil değil ama aynı kartı kullanıyor — çapraz pattern)
UPDATE shop.payment_method SET card_fingerprint = REPLICATE('Y', 64) WHERE customer_id IN (4, 39);

PRINT '> 50 payment_method eklendi (ring C ve D fingerprint güncellendi)';
GO

-- ----------------------------------------------------------------------------
-- Siparişler ve sipariş satırları (400 sipariş, ~1000 satır)
-- ----------------------------------------------------------------------------
DECLARE @baseline DATETIME2 = '2026-01-01';

-- Deterministik sipariş üretimi: her müşteri 6-10 sipariş; her sipariş 2-4 ürün
DECLARE @order_id BIGINT = 10001;
DECLARE @cust INT = 1;

WHILE @cust <= 50
BEGIN
    DECLARE @order_count INT = 6 + (@cust % 5);  -- 6-10
    DECLARE @oi INT = 0;
    WHILE @oi < @order_count AND @order_id <= 10400
    BEGIN
        DECLARE @day_offset INT = (@cust * 3 + @oi * 7) % 110;
        DECLARE @line_count INT = 2 + ((@cust + @oi) % 3);  -- 2-4
        DECLARE @pmid2 BIGINT = @cust;  -- her müşterinin ilk kartı

        INSERT INTO shop.[order] (order_id, customer_id, payment_method_id, device_id, order_date, status, total_amount)
        VALUES (
            @order_id, @cust, @pmid2,
            CASE
                WHEN @cust IN (2, 7, 15)            THEN 101
                WHEN @cust = 10                     THEN 110
                WHEN @cust = 18                     THEN 111
                WHEN @cust = 22                     THEN 112
                WHEN @cust = 30                     THEN 113
                WHEN @cust = 42                     THEN 114
                WHEN @cust = 8                      THEN 120
                WHEN @cust = 33                     THEN 121
                WHEN @cust IN (4, 12, 24)           THEN 130
                ELSE 200 + ((@cust - 1) % 71)
            END,
            DATEADD(DAY, @day_offset, @baseline),
            'paid',
            0  -- aşağıda toplanacak
        );

        DECLARE @li INT = 0;
        DECLARE @line_total DECIMAL(14, 2) = 0;
        WHILE @li < @line_count
        BEGIN
            DECLARE @prod_id INT = 1001 + ((@cust * 13 + @oi * 19 + @li * 23) % 120);
            DECLARE @qty INT = 1 + (@li % 2);
            DECLARE @unit DECIMAL(12, 2) = (SELECT price FROM shop.product WHERE product_id = @prod_id);

            -- Aynı sipariş içinde aynı ürün gelirse atla
            IF NOT EXISTS (SELECT 1 FROM shop.order_line WHERE order_id = @order_id AND product_id = @prod_id)
            BEGIN
                INSERT INTO shop.order_line (order_id, product_id, quantity, unit_price)
                VALUES (@order_id, @prod_id, @qty, @unit);
                SET @line_total = @line_total + @qty * @unit;
            END
            SET @li = @li + 1;
        END

        UPDATE shop.[order] SET total_amount = @line_total WHERE order_id = @order_id;

        SET @order_id = @order_id + 1;
        SET @oi = @oi + 1;
    END
    SET @cust = @cust + 1;
END

PRINT '> Siparişler eklendi (' + CAST(@order_id - 10001 AS VARCHAR) + ' adet)';
GO

-- Product view (basit — co-purchase yan sinyali)
DECLARE @baseline DATETIME2 = '2026-01-01';
INSERT INTO shop.product_view (customer_id, product_id, viewed_at)
SELECT
    o.customer_id,
    ol.product_id,
    DATEADD(MINUTE, -((o.order_id % 1440)), o.order_date)
FROM shop.[order] o
JOIN shop.order_line ol ON ol.order_id = o.order_id;

PRINT '> product_view eklendi';
GO

PRINT '> shop seed tamam';
SELECT 'product'        AS entity, COUNT(*) AS n FROM shop.product
UNION ALL SELECT 'customer',         COUNT(*) FROM shop.customer
UNION ALL SELECT 'device',           COUNT(*) FROM shop.device
UNION ALL SELECT 'customer_device',  COUNT(*) FROM shop.customer_device
UNION ALL SELECT 'payment_method',   COUNT(*) FROM shop.payment_method
UNION ALL SELECT 'order',            COUNT(*) FROM shop.[order]
UNION ALL SELECT 'order_line',       COUNT(*) FROM shop.order_line
UNION ALL SELECT 'product_view',     COUNT(*) FROM shop.product_view;
GO
