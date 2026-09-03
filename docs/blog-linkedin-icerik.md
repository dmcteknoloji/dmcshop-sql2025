# İçerik paketi — DMCShop / SQL Server 2025

İki parça: (1) WordPress blog yazısı, (2) LinkedIn postu. İkisi de Türkçe, DMC Teknoloji sesiyle.

---
---

# 1) WORDPRESS BLOG YAZISI

> **Yayın notu:** WordPress blok editörüne yapıştırırken Markdown desteği yoksa başlıkları
> `Başlık` bloğu, kod parçalarını `Kod` bloğu olarak ekle. Önerilen kategori: *SQL Server*,
> *Yapay Zekâ*, *Veri Mimarisi*. Öne çıkan görsel için repo'daki `docs/assets/banner.svg`.

---

**SEO Başlık (60 karakter altı):**
SQL Server 2025: Vector, Graph ve RAG Tek Veritabanında

**Meta açıklama (155 karakter):**
Vector arama, graph fraud tespiti ve RAG asistanı ayrı sistemler kurmadan tek SQL Server 2025 veritabanında. DMCShop açık kaynak referans uygulamasıyla uçtan uca anlattık.

**URL slug:** `sql-server-2025-vector-graph-rag-dmcshop`

**Etiketler:** SQL Server 2025, VECTOR, DiskANN, Graph Database, RAG, .NET 10, Yapay Zekâ, Semantik Arama, Fraud Tespiti

---

## SQL Server 2025: Vector, Graph ve RAG'ı Tek Veritabanında Birleştirmek — DMCShop Referans Uygulaması

Bir e-ticaret platformunda modern yapay zekâ özelliklerini hayata geçirmek istediğinizde, klasik mimari size genelde dört ayrı sistem önerir: anlamsal arama için bir **vektör veritabanı** (Pinecone, Qdrant), ilişki analizi için bir **graph veritabanı** (Neo4j), sohbet asistanı için bir **RAG servis katmanı** ve tüm bunları besleyen **ana ilişkisel veritabanı**. Dört ayrı sistem; dört ayrı yedekleme stratejisi, dört ayrı yetkilendirme modeli, dört ayrı operasyon yükü.

SQL Server 2025 bu denklemi değiştiriyor. Vektör arama, graph dolaşımı, harici AI model entegrasyonu ve uçtan uca RAG — hepsi **aynı veritabanı motorunda, aynı `SELECT` içinde, aynı yedeklemenin altında** çalışıyor.

Bunu somut bir örnekle göstermek için **DMCShop**'u geliştirdik: 50.000+ ürünlük gerçek ölçekli bir e-ticaret kataloğu üzerinde anlamsal arama, ürün önerisi, RAG asistanı ve fraud ring tespitini uçtan uca çalıştıran, **açık kaynak (MIT)** bir referans uygulaması.

🔗 **Canlı demo:** [demo.dmcteknoloji.com](https://demo.dmcteknoloji.com)
🔗 **Kaynak kod:** [github.com/dmcteknoloji/dmcshop-sql2025](https://github.com/dmcteknoloji/dmcshop-sql2025)

---

### Neyi çözüyoruz?

Geleneksel yaklaşımda "ürün için anlamsal arama + birlikte alınan ürün önerisi + sohbet asistanı + fraud tespiti" demek, en az üç farklı uzmanlık alanı ve üç farklı altyapı demekti. Veriyi senkronize tutmak (ürün eklendiğinde hem SQL'e hem vektör DB'sine hem graph DB'sine yazmak), tutarlılığı sağlamak ve hepsini güvende tutmak başlı başına bir proje.

SQL Server 2025'in getirdiği yenliklerle bu senaryoların tamamı tek motorda toplanıyor:

| İhtiyaç | Klasik çözüm | SQL Server 2025 |
|---|---|---|
| Anlamsal arama | Pinecone / Qdrant | `VECTOR(N)` tipi + `CREATE VECTOR INDEX` (DiskANN) |
| Embedding üretimi | Ayrı Python servisi | `AI_GENERATE_EMBEDDINGS` + `CREATE EXTERNAL MODEL` |
| Vektör sorgusu | Vektör DB API'si | `VECTOR_SEARCH(...)` T-SQL fonksiyonu |
| İlişki / öneri analizi | Neo4j | `GRAPH MATCH` + `SHORTEST_PATH` |
| RAG asistanı | LangChain + servis | T-SQL içinde embed → search → chat → audit |

---

### DMCShop nedir?

DMCShop, SQL Server 2025'in `VECTOR(N) + DiskANN` ve `GRAPH MATCH + SHORTEST_PATH` özelliklerinin **üretim senaryolarındaki** karşılığını gösteren açık kaynak bir referans uygulamasıdır. Mock veri yok — gerçek ölçekte çalışıyor:

| Varlık | Adet |
|---|---:|
| Kategori | 100 (10 ana × 10 alt) |
| Ürün | **50.120** |
| Müşteri | 10.050 |
| Sipariş | 100.400 |
| Sipariş satırı | 451.202 |
| Cihaz | 4.080 |
| Tespit edilen fraud ring | ~1.000 |
| Vektör embedding | 50.000+ (`nomic-embed-text`, 768 boyut, DiskANN cosine) |

Teknoloji yığını: **.NET 10**, **Blazor Server**, **EF Core 10**, embedding ve sohbet için **Ollama** (`nomic-embed-text` + `qwen2.5:3b-instruct`), tek Azure B4ms VM (4 vCPU / 16 GB) üzerinde canlı; aynı yığın local `docker-compose` ile birebir çalışıyor.

---

### Beş senaryo, tek veritabanı

#### 1. Semantik ürün arama — `VECTOR_SEARCH` + DiskANN

Kullanıcı "rahat ergonomik klavye" yazdığında, kelime eşleşmesi (`LIKE`) çoğu zaman sıfır sonuç döner. Anlamsal arama ise ergonomik ofis ürünlerini — mouse pad, MX Master mouse, rahat ayakkabı — semantik uzayda yakın olduğu için getirir.

```sql
USE dmcshop;
DECLARE @q VECTOR(768) = AI_GENERATE_EMBEDDINGS(
    N'rahat ergonomik klavye' USE MODEL ollama_embed_text
);

WITH hits AS (
    SELECT * FROM VECTOR_SEARCH(
        TABLE      = vector.product_embedding,
        COLUMN     = embedding_ollama_768,
        SIMILAR_TO = @q,
        METRIC     = 'cosine',
        TOP_N      = 5)
)
SELECT h.product_id, p.name, h.distance
FROM   hits h JOIN shop.product p ON p.product_id = h.product_id
ORDER BY h.distance;
```

Demoda vektör sorgusu ~150 ms, `LIKE` sorgusu ~10 ms sürer; ama `LIKE` çoğu sorguda boş döner. Anlam vs. lafzi arama farkı yan yana görülür.

#### 2. RAG tabanlı ürün asistanı — embed → retrieval → chat → audit

`/asistan` sayfasında "1500 TL altı ergonomik mouse" sorusu uçtan uca tek akışta yanıtlanır: soru embed edilir, vektör arama ile en alakalı 5 ürün getirilir, sohbet modeli bu bağlamla **token-token** yanıt üretir ve her çağrı `vector.query_log` tablosunda denetim için kayda alınır. Streaming yanıt, SignalR ile tarayıcıya canlı akar.

İlk soru modelin RAM'e yüklenmesiyle ~15 sn (cold-start); sonraki sorular cache'li, ~3-5 sn.

#### 3. Fraud ring tespiti — `GRAPH MATCH` + `SHORTEST_PATH`

Aynı cihaz parmak izini, aynı IP'yi veya aynı kartı paylaşan müşteri kümeleri graph dolaşımıyla bulunur. En etkileyici kısım: dolandırıcılık zincirinin kanıtı doğrudan okunabilir bir metne dönüşür.

```sql
SELECT
    cn1.display_name AS start_customer,
    STRING_AGG(cn2.display_name, N' → ')
        WITHIN GROUP (GRAPH PATH) AS hops
FROM graph.customer_node AS cn1,
     graph.uses_device FOR PATH AS ud1,
     graph.device_node FOR PATH AS dn,
     graph.uses_device FOR PATH AS ud2,
     graph.customer_node FOR PATH AS cn2
WHERE MATCH(SHORTEST_PATH(cn1(-(ud1)->dn<-(ud2)-cn2)+))
  AND cn1.customer_id = 10;
```

`STRING_AGG ... WITHIN GROUP (GRAPH PATH)` ifadesiyle bir dolandırıcılık yolu doğrudan "Ali → Ayşe → Mehmet" gibi bir kanıt zincirine dönüşür. Müfettiş için anında rapor.

#### 4. "Bunu alanlar bunu da aldı" — `GRAPH MATCH` 2-hop

Klasik co-purchase önerisi, ilişkisel JOIN ile yazıldığında 50+ satırı bulur. Graph diliyle tek bir `MATCH` yeter:

```sql
SELECT TOP (10) p2_shop.name, COUNT(DISTINCT c.customer_id) AS co_buyer_count
FROM graph.product_node p1, graph.purchased pur1,
     graph.customer_node c,
     graph.purchased pur2, graph.product_node p2,
     shop.product p2_shop
WHERE MATCH(p1<-(pur1)-c-(pur2)->p2)
  AND p1.product_id = 1041
  AND p2.product_id <> 1041
  AND p2_shop.product_id = p2.product_id
GROUP BY p2.product_id, p2_shop.name
ORDER BY co_buyer_count DESC;
```

#### 5. "Sana özel" — Vector + Graph hibrit öneri

En ileri senaryo: müşterinin son siparişlerinin embedding centroid'i hesaplanır, `VECTOR_SEARCH` ile benzer ürünler bulunur, ardından `GRAPH MATCH` ile bu ürünlerin sosyal kanıtı (kaç kişi birlikte aldı) skora katılır. Hibrit skor = `mesafe + 1/(1+sosyal)`. Anlamsal benzerlik ve davranışsal sinyal **tek sorguda** birleşir.

---

### Üretimden çıkan üç gerçek not (RTM-CU4)

Belgelerin anlatmadığı, sahada öğrenilen nüanslar — workshop'larda en çok soru alan kısım:

1. **VECTOR tipi preview bayrağıyla açılır.** `ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;`
2. **DiskANN vektör indeksi varken tabloya hiçbir DML yapılamaz** (`Msg 42231` — INSERT, UPDATE ve DELETE hepsi reddedilir). Tek yol: önce `DROP INDEX`, sonra DML, sonra yeniden `CREATE VECTOR INDEX`. Toplu embedding yüklemesini buna göre tasarlamak gerekir.
3. **`VECTOR_SEARCH` sözdizimi değişti.** Eski `TOP (N) WITH APPROXIMATE` RTM'de yok; çıktı bir CTE içinde tutulup dışarıda JOIN'lenmeli (yukarıdaki örneklerdeki desen).

Bu tür detaylar, "demo'da çalışıyor"dan "üretimde çalışıyor"a geçişin farkıdır.

---

### Mimari: üç katman, tek VM

DMCShop tek bir Azure B4ms VM üzerinde (4 vCPU / 16 GB) çalışır; HTTPS için Caddy 2 + Let's Encrypt, otomatik sertifika yenileme. Tüm kurulum tek komutla otomatize:

```bash
git clone https://github.com/dmcteknoloji/dmcshop-sql2025.git
cd dmcshop-sql2025
./scripts/setup.sh                       # showcase (120 ürün, ~3 dk)
# veya
DMCSHOP_SCALE=large ./scripts/setup.sh   # kurumsal (50K ürün, ~45 dk)
dotnet run --project app/src/DMCShop.Web # http://localhost:5295
```

`setup.sh` idempotent: container, model, schema, seed, embedding ve DiskANN indeksini uçtan uca yönetir.

---

### Ne zaman SQL Server VECTOR, ne zaman ayrı bir vektör DB?

Dürüst olmak gerekirse her senaryo için tek doğru yok. Milyarlarca vektör ve aşırı yüksek QPS gerektiren saf vektör iş yüklerinde özelleşmiş vektör veritabanları hâlâ güçlü. Ama verinizin zaten SQL Server'da olduğu, vektör + graph + ilişkisel sorguların **birlikte** çalışması gereken kurumsal senaryolarda; tek motorda toplama, operasyon ve tutarlılık açısından ciddi bir kazanç sağlıyor. Mikroservis dağıtımı yok, veri senkronizasyonu yok, tek yedekleme, tek yetki sistemi.

---

### Denemek için

- **Canlı demo:** [demo.dmcteknoloji.com](https://demo.dmcteknoloji.com)
- **Kaynak kod (MIT):** [github.com/dmcteknoloji/dmcshop-sql2025](https://github.com/dmcteknoloji/dmcshop-sql2025)
- **Workshop handbook (60-90 dk uçtan uca tur):** repo içindeki `docs/handbook.md`

DMCShop, **SQL Server 2025: Herkes İçin, Her Rol İçin** kitabının canlı çalışan karşılığıdır. Kitabın 32 bölümünden her birinin demoda hangi sayfa, T-SQL dosyası veya .NET kodu ile karşılandığı `docs/kitap-demo-koprusu.md` içinde eşleştirilmiştir — kitabı okurken yan ekranda demoyu açıp bölümün canlı karşılığını görebilirsiniz.

---

*Açık kaynak · MIT · © 2026 [Çağlar Özenç](https://www.linkedin.com/in/caglarozenc) & DMC Bilgi Teknolojileri. Sorularınız için: iletisim@dmcteknoloji.com*

---
---

# 2) LINKEDIN POSTU

> **Not:** LinkedIn'de Markdown render edilmez. Aşağıdaki metni düz olarak yapıştır;
> emoji ve satır boşlukları olduğu gibi korunur. İlk 2 satır "görünür alan" — kanca orada.

---

Vector DB + Graph DB + RAG servisi + ana veritabanı = 4 ayrı sistem, 4 ayrı operasyon yükü.

SQL Server 2025 bu denklemi tek motora indiriyor. Kanıtlamak için açık kaynak bir referans uygulama yazdık. 👇

🛒 DMCShop — 50.000+ ürünlük gerçek ölçekli bir e-ticaret kataloğu. Üzerinde 4 senaryo, hepsi AYNI veritabanında:

🔍 Semantik arama → VECTOR(768) + DiskANN index
🤖 RAG asistanı → embed → VECTOR_SEARCH → chat, uçtan uca T-SQL içinde, streaming yanıt
🕵️ Fraud ring tespiti → GRAPH MATCH + SHORTEST_PATH (dolandırıcılık zinciri okunabilir bir metne dönüşüyor)
🛍️ "Bunu alanlar bunu da aldı" → graph 2-hop, tek SELECT

Neo4j yok. Pinecone yok. Ayrı RAG servisi yok. Tek SELECT motoru, tek yedekleme, tek yetki sistemi.

Üretimden çıkan en kıymetli ders: DiskANN vektör indeksi varken tabloya hiçbir DML yapılamıyor (Msg 42231) — toplu embedding yüklemesini buna göre tasarlamak gerekiyor. Bu tür detaylar "demoda çalışıyor" ile "üretimde çalışıyor" arasındaki farkı belirliyor.

Tamamı açık kaynak (MIT), canlı demo ayakta, tek komutla kuruluyor:

🔗 Demo: demo.dmcteknoloji.com
🔗 Kod: github.com/dmcteknoloji/dmcshop-sql2025

Stack: .NET 10 · Blazor Server · EF Core 10 · Ollama (nomic-embed-text + qwen2.5)

SQL Server VECTOR'ü mü yoksa ayrı bir vektör veritabanını mı tercih edersiniz — hangi senaryoda hangisi? Yorumlarda konuşalım. 👇

#SQLServer2025 #VectorSearch #GraphDatabase #RAG #YapayZeka #DotNet #VeriMimarisi #DMCTeknoloji

---
---

# 3) X (TWITTER) THREAD

> **Not:** Her tweet 280 karakter altında. `🧵` ile başla, numaralandırma (1/8 …) akışı tutar.
> Link içeren tweet'i thread'in ortasına değil, ilk veya son tweet'e koymak erişim için daha iyi.

---

**1/8** 🧵
Anlamsal arama için Pinecone.
İlişki analizi için Neo4j.
Sohbet için ayrı bir RAG servisi.
Bir de ana veritabanı.

4 sistem, 4 operasyon yükü.

SQL Server 2025 bunu tek motora indiriyor. Kanıtlamak için açık kaynak bir uygulama yazdık 👇

---

**2/8**
🛒 DMCShop: 50.000+ ürünlük gerçek ölçekli bir e-ticaret kataloğu.

Üzerinde 4 AI senaryosu — hepsi AYNI veritabanında, aynı SELECT motorunda, aynı yedeklemenin altında.

Neo4j yok. Pinecone yok. Ayrı RAG servisi yok.

---

**3/8**
🔍 Semantik arama

VECTOR(768) tipi + DiskANN index.

"rahat ergonomik klavye" → LIKE sıfır sonuç döner; vektör arama ergonomik ofis ürünlerini semantik yakınlıkla getirir.

AI_GENERATE_EMBEDDINGS + VECTOR_SEARCH, hepsi T-SQL.

---

**4/8**
🤖 RAG asistanı

embed → VECTOR_SEARCH → chat → audit log.
Hepsi veritabanının içinde, token-token streaming yanıt.

LangChain'e, ayrı bir Python servisine gerek yok.

---

**5/8**
🕵️ Fraud ring tespiti

GRAPH MATCH + SHORTEST_PATH ile aynı cihaz/IP/kartı paylaşan müşteri kümeleri bulunuyor.

En güzeli: STRING_AGG ... WITHIN GROUP (GRAPH PATH) dolandırıcılık zincirini "Ali → Ayşe → Mehmet" gibi okunabilir bir kanıta çeviriyor.

---

**6/8**
🛍️ "Bunu alanlar bunu da aldı"

Co-purchase önerisi ilişkisel JOIN ile 50+ satır.
Graph diliyle tek MATCH:

MATCH(p1<-(pur1)-c-(pur2)->p2)

Tek SELECT. Bitti.

---

**7/8**
Üretimden en kıymetli ders:

DiskANN vektör indeksi varken tabloya hiçbir DML yapılamıyor (Msg 42231) — INSERT/UPDATE/DELETE hepsi reddediliyor.

Toplu embedding yüklemesini buna göre tasarlamak gerekiyor. "Demoda çalışıyor" ≠ "üretimde çalışıyor".

---

**8/8**
Tamamı açık kaynak (MIT), canlı demo ayakta, tek komutla kuruluyor.

Stack: .NET 10 · Blazor Server · EF Core 10 · Ollama

🔗 Demo: demo.dmcteknoloji.com
🔗 Kod: github.com/dmcteknoloji/dmcshop-sql2025

SQL Server VECTOR mü, ayrı vektör DB mi? Hangi senaryoda hangisi?

#SQLServer2025 #RAG #DotNet
