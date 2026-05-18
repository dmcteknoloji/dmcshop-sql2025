# DMCShop Workshop Handbook

> Bu doküman, DMCShop'u workshop ortamında veya kendi makinende **uçtan uca** çalıştırmak,
> dört senaryoyu sırayla göstermek ve SQL Server 2025'in vector + graph özelliklerini
> yerinde sergilemek için adım adım kılavuzdur.

<p align="center">
  <img src="assets/setup-flow.svg" alt="DMCShop setup flow — adım adım kurulum" width="100%" />
</p>

---

## 0 — Kim için, ne için

| Hedef kitle                           | Beklenen çıkış                                                              |
| ------------------------------------- | --------------------------------------------------------------------------- |
| SQL Server 2025 kitap okurları        | Vector + graph özelliklerini gerçek e-ticaret senaryosunda gözle gör        |
| DBA / data engineer                   | DiskANN performans karakteristiği, graph MATCH/SHORTEST_PATH pratiği         |
| .NET geliştirici                      | EF Core 10 + raw SQL hibrit kullanım, IEmbeddingProvider switching          |
| Çözüm mimarı                          | Vector + graph birlikteliğinin "tek DB'de RAG + fraud" referansı            |

Workshop süresi: **60-90 dakika** önerilen tur. Hızlı tur 30 dakikada mümkün.

---

## 1 — Hazırlık (5 dakika)

### 1.1 Önkoşul kurulumu

| Araç           | Mac                                       | Linux                           | Windows                       |
| -------------- | ----------------------------------------- | ------------------------------- | ----------------------------- |
| Docker         | Docker Desktop                            | `docker.io` paket                | Docker Desktop                |
| .NET 10 SDK    | dotnet-install.sh / .pkg                  | apt: `dotnet-sdk-10.0`          | .NET installer                |
| sqlcmd         | `brew install sqlcmd`                     | mssql-tools18 apt repo          | SSMS bundle                   |
| git            | Xcode CLT                                 | apt                              | git for Windows               |

> RAM önerisi: **en az 8 GB**, kurumsal scale için **16 GB**. Chat modeli ~3 GB,
> SQL Server ~2 GB, model loading cache ~3 GB.

### 1.2 Repo'yu al

```bash
git clone https://github.com/dmcteknoloji/dmcshop-sql2025.git
cd dmcshop-sql2025
```

---

## 2 — Tek komutla kurulum (3-45 dakika)

`scripts/setup.sh` 7 adımı sırayla yürütür. Her adım idempotent — yeniden çalıştırılabilir,
sadece eksik kısımlar tekrarlanır.

```bash
./scripts/setup.sh                       # showcase (120 ürün, ~3 dakika)
DMCSHOP_SCALE=large ./scripts/setup.sh   # kurumsal (50K ürün, ~45 dakika)
```

### Adım adım ne oluyor

| # | Adım                  | Süre (showcase) | Süre (large) | Detay                                                          |
| - | --------------------- | --------------- | ------------ | -------------------------------------------------------------- |
| 1 | Docker container      | ~30 sn          | ~30 sn       | mssql + ollama; restart: unless-stopped                        |
| 2 | Ollama modelleri      | ~2-4 dk          | ~2-4 dk      | nomic-embed-text (270 MB) + qwen2.5:3b-instruct (2 GB)         |
| 3 | Schema + showcase     | ~20 sn          | ~20 sn       | bootstrap.sh → 4 schema + 120 ürün                              |
| 4 | (Opsiyonel) kurumsal  | —               | ~2 dk        | sql/30-33: +50K ürün, +10K müşteri, +100K sipariş               |
| 5 | Vector tablo INSERT   | ~2 sn           | ~5 sn        | DROP index, eksik product_embedding satırı ekle                 |
| 6 | Embedding üretimi     | ~15 sn          | ~50 dk       | Ollama nomic-embed-text, batch 32, paralel                      |
| 7 | DiskANN index         | ~1 sn           | ~70 sn       | CREATE VECTOR INDEX (sqlcmd -t 600 timeout aşımı önlemi)         |

### Uygulamayı başlat

```bash
dotnet run --project app/src/DMCShop.Web
```

Tarayıcı: **http://localhost:5295**

---

## 3 — Senaryo turu (60 dakika)

### 3.1 Anasayfa (5 dakika)

Tarayıcıdan `/` aç. Demo veri tabanı bandında **canlı sayımlar** (50.120 ürün,
10.050 müşteri, 100.400 sipariş, 451.202 satır, ...) — `DbContext.CountAsync()`
ile her sayfa açılışında DB'den çekilir.

Üst başlıkta TR + UTC saat yan yana — kurumsal mimari göstergesi.

> **Workshop ipucu**: SSMS'i yan ekrana aç. `SELECT COUNT(*) FROM shop.product`
> ile aynı rakamı göster — "uygulama gerçek DB'den okuyor, mock data yok" mesajı.

### 3.2 Senaryo 1: Semantik arama (15 dakika)

`/search` sayfası. Sağ üstte provider rozeti: `Provider: ollama / nomic-embed-text / 768 dim`.

**Demo adımları**:

1. Arama kutusuna `rahat ergonomik klavye` yaz, **Ara**'ya bas.
2. **Sol panel (Vector)**: 5 ürün geliyor — Mouse Pad XL, Logitech MX Master, rahat
   ayakkabı, mouse pad — anlamsal yakınlık (klavye kelime geçmiyor ama "ergonomik
   ofis" semantik uzayda yakın).
3. **Sağ panel (LIKE)**: çoğunlukla 0 sonuç veya sadece `description_tr` içinde
   "klavye" tam metin geçen ürünler.
4. Latency rozeti: vector ~150 ms, LIKE ~10 ms (B4ms üzerinde).

**T-SQL versiyonu** (SSMS'te göster):

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

> **Workshop ipucu**: aynı sorguyu `LIKE` ile yaz, "klavye" kelimesi geçmeyen sorgu
> sıfır sonuç verir — semantic vs lexical kontrast.

### 3.3 Senaryo 4: Co-purchase (10 dakika)

`/urun/1041` (Etiyopya Kahve Çekirdeği) aç. Sayfanın altında **"Bunu alanlar bunu
da aldı"** bandı — Mum Lavanta, Vanilya Çubuk, Logitech Mouse, ... 9 öneri kartı.

Her kartın altında "X müşteri birlikte aldı" badge'i.

**T-SQL versiyonu**:

```sql
SELECT TOP (10)
    p2.product_id,
    p2_shop.name,
    COUNT(DISTINCT c.customer_id) AS co_buyer_count
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

> **"Aaa" anı**: graph traversal **tek query** ile yapılır. Aynı şeyi relational
> JOIN ile yazarsan 50+ satır. Graph dili insan beynine yakın.

### 3.4 Senaryo 3: Fraud ring tespiti (15 dakika)

`/fraud` aç. Üst tarafta özet: toplam ring sayısı, HIGH + MEDIUM dağılımı,
pattern başına sayı.

**3 pattern**:
- **Paylaşılan cihaz** — aynı `device.fingerprint` farklı müşteriler
- **Paylaşılan IP** — aynı `ip_address`'i kullanan farklı device'lar
- **Paylaşılan kart** — aynı `card_fingerprint` farklı müşteriler

**Demo adımları**:

1. Sıralama dropdown'undan **Risk seviyesi (HIGH önce)** seç.
2. İlk ringler büyük müşteri kümeleri içeriyor — evidence panel'inde "Aynı cihaz
   parmak izi (fp:aaaaa...) 5 müşteri tarafından kullanılıyor".
3. Sağ üstte müşteri sayısı (örn. `5`), aşağıda bağlı müşterilerin chip listesi.
4. Arama kutusuna bir müşteri adı yaz (örn. `Ayşe`) — eşleşen chip vurgulanır.

**T-SQL versiyonu** — SHORTEST_PATH ile evidence chain:

```sql
SELECT *
FROM (
    SELECT
        cn1.display_name AS start_customer,
        LAST_VALUE(cn2.display_name) WITHIN GROUP (GRAPH PATH) AS end_customer,
        STRING_AGG(cn2.display_name, N' → ')
            WITHIN GROUP (GRAPH PATH) AS hops
    FROM graph.customer_node AS cn1,
         graph.uses_device FOR PATH AS ud1,
         graph.device_node FOR PATH AS dn,
         graph.uses_device FOR PATH AS ud2,
         graph.customer_node FOR PATH AS cn2
    WHERE MATCH(SHORTEST_PATH(cn1(-(ud1)->dn<-(ud2)-cn2)+))
      AND cn1.customer_id = 10
) AS sp
WHERE sp.end_customer IS NOT NULL
  AND sp.hop_count BETWEEN 2 AND 6;
```

> **"Aaa" anı**: `STRING_AGG ... WITHIN GROUP (GRAPH PATH)` — yol literal olarak
> string'e dönüşür. Müfettiş için doğrudan rapor.

### 3.5 Senaryo 2: RAG asistan (15 dakika)

`/asistan` aç. Üst rozetler: Retrieval + Chat modeli.

**Demo adımları**:

1. Örnek chip'lerden `1500 TL altı ergonomik mouse` seç.
2. Durum göstergesi: pulse-amber dot → **"Vector retrieval — ilgili ürünler aranıyor"**
3. Hits yüklendikten sonra: pulse-green → **"Model yanıt yazıyor"** + ▍ caret
4. Token-by-token yanıt akar (qwen2.5:3b ~12 token/sn).
5. Bittiğinde: yeşil dot → **"Tamamlandı"** + retrieval/LLM/total latency.
6. Detaylar açılır: kullanılan 5 ürün kart grid'i.

> **İlk soru** model RAM'e ilk kez yüklenirken cold-start (~15 sn).
> **Sonraki sorular** ~3-5 sn — model cache'li, sadece inference.

SSMS'te paralel: `SELECT TOP 5 * FROM vector.query_log ORDER BY query_id DESC` — her
çağrı audit'lenmiş, latency + used_product_ids JSON formatında.

---

## 4 — Workshop kapanışı

**Mesaj**: SQL Server 2025, **tek bir veri tabanında** vector arama, graph traversal,
RAG ve fraud tespitini birlikte yürütür. Mikroservis dağıtımı, vector DB ayrımı,
graph DB ayrımı yok — aynı `SELECT` motoru, aynı backup, aynı yetki sistemi.

**Tartışma soruları**:
- Bu modeli ne zaman kullanır, ne zaman tercih etmez (Pinecone vs SQL Server VECTOR)?
- DiskANN tuning parametrelerine ihtiyaç var mı? Workshop ölçeği ne kadarı yansıtıyor?
- Streaming chat workshop ortamında neden değerli — ürünleşme için ne fark eder?

---

## 5 — Sorun giderme — yaygın sorular

### "Asistan hatası: Cannot find a vector index with metric 'cosine'"

Vector index drop edildi ama henüz yeniden oluşturulmadı. `scripts/setup.sh`
adım 7'yi tekrar çalıştır veya manuel:

```sql
CREATE VECTOR INDEX vix_pe_ollama
ON vector.product_embedding (embedding_ollama_768)
WITH (METRIC = 'cosine', TYPE = 'DiskANN', MAXDOP = 4);
```

### "Msg 42231: Data modification ... vector index"

Index varken DML yasak. Önce drop, sonra DML, sonra recreate.

### Asistan ilk soruda uzun bekliyor

Cold-start: chat modeli RAM'e yükleniyor. 3B model ~12-15 sn, 8B ~30 sn. Sonraki
sorular cache'li (~3-5 sn).

### Embedding çok yavaş

- `--batch 64` ile daha büyük batch
- B4ms 4 vCPU ile ~1.000 ürün/dk beklenir; daha hızlı için A4 v2 / D4s v3

### Daha fazla detay

[docs/01-getting-started.md](01-getting-started.md) içinde tüm sorun giderme bandı var.

---

## 6 — Sonraki adımlar

| Hedef                            | Yapılacak                                                |
| -------------------------------- | -------------------------------------------------------- |
| Kendi kataloğunla denemek         | shop.product'ı kendi verinle değiştir, embed-products çalıştır |
| Azure OpenAI'ya geçmek            | appsettings.Provider.Active = "openai" + endpoint + key  |
| HTTPS + custom domain             | Caddy + Let's Encrypt — yol haritasında                  |
| Container Apps autoscale          | Mimari refaktör — yol haritasında                        |
| Workshop ekran kayıtları          | yakında                                                  |

---

## Lisans ve iletişim

[MIT](../LICENSE) · © 2026 Çağlar Özenç & DMC Bilgi Teknolojileri
[`iletisim@dmcteknoloji.com`](mailto:iletisim@dmcteknoloji.com)
