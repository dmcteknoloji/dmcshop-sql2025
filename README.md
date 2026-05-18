<p align="center">
  <img src="docs/assets/banner.svg" alt="DMCShop — SQL Server 2025 graph + vector reference application" width="100%" />
</p>

<p align="center">
  <a href="https://learn.microsoft.com/sql/sql-server/what-s-new-in-sql-server-2025"><img alt="SQL Server 2025" src="https://img.shields.io/badge/SQL%20Server-2025%20RTM--CU4-A4262C?style=for-the-badge&logo=microsoftsqlserver&logoColor=white"></a>
  <a href="https://dotnet.microsoft.com/"><img alt=".NET 10" src="https://img.shields.io/badge/.NET-10.0-512BD4?style=for-the-badge&logo=dotnet&logoColor=white"></a>
  <a href="https://learn.microsoft.com/aspnet/core/blazor/"><img alt="Blazor Server" src="https://img.shields.io/badge/Blazor-Server-512BD4?style=for-the-badge&logo=blazor&logoColor=white"></a>
  <a href="https://learn.microsoft.com/ef/core/"><img alt="EF Core 10" src="https://img.shields.io/badge/EF%20Core-10.0-512BD4?style=for-the-badge&logo=dotnet&logoColor=white"></a>
  <a href="https://ollama.com/"><img alt="Ollama" src="https://img.shields.io/badge/Ollama-nomic--embed%20%2B%20qwen2.5-000000?style=for-the-badge&logo=ollama&logoColor=white"></a>
  <a href="https://azure.microsoft.com/"><img alt="Azure" src="https://img.shields.io/badge/Azure-VM%20deploy-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white"></a>
  <br/>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-2EA043?style=flat-square"></a>
  <img alt="Status: Active" src="https://img.shields.io/badge/durum-aktif%20demo-2EA043?style=flat-square">
  <img alt="Scale" src="https://img.shields.io/badge/ölçek-50K%20ürün%20·%20100K%20sipariş-A4262C?style=flat-square">
</p>

> **DMCShop**, SQL Server 2025'in yerleşik `VECTOR(N) + DiskANN` ve `GRAPH MATCH + SHORTEST_PATH`
> özelliklerinin üretim senaryolarındaki karşılığını gösteren açık kaynak referans uygulamadır.
> Klasik bir e-ticaret kataloğu üzerinde **anlamsal arama**, **ürün önerisi**, **RAG asistan**
> ve **fraud ring tespiti** uçtan uca aynı veri tabanı üzerinde çalışır.

<p align="center">
  <strong>Canlı demo:</strong>
  <a href="http://dmcshop-eqaspinoarx3g.westeurope.cloudapp.azure.com">
    http://dmcshop-eqaspinoarx3g.westeurope.cloudapp.azure.com
  </a>
</p>

---

## Demo veri tabanı ölçeği

| Entity              |     Adet | Açıklama                                                            |
| ------------------- | -------: | ------------------------------------------------------------------- |
| Kategori            |      100 | 10 ana × 10 alt — kitap, elektronik, gıda, giyim, ev, hobi, ...     |
| Ürün                | **50.120** | 120 showcase (elle yazılmış) + 50.000 T-SQL CROSS JOIN üreteç      |
| Müşteri             |   10.050 | Türkçe rastgele ad-soyad-şehir                                      |
| Sipariş             |  100.400 | 2026 ilk 4 ayına yayılmış                                           |
| Sipariş satırı      |  451.202 | Ortalama 4.5 satır/sipariş                                          |
| Cihaz               |    4.080 | IP, parmak izi, user-agent                                          |
| Fraud ring (tespit) |    ~1000 | Paylaşılan cihaz / IP / kart desenleri                              |
| Vector embedding    |    50K+ | Ollama `nomic-embed-text` (768 dim) · DiskANN cosine                |

---

## Senaryolar

| # | Senaryo                          | Özellik                            | UI                                                   |
| - | -------------------------------- | ---------------------------------- | ---------------------------------------------------- |
| 1 | **Semantik ürün arama**          | `VECTOR_SEARCH` + DiskANN          | [`/search`](docs/02-senaryo-semantic-search.md)      |
| 2 | **RAG tabanlı ürün asistanı**    | Retrieval + chat (streaming)       | [`/asistan`](docs/03-senaryo-rag-asistan.md)         |
| 3 | **Fraud ring tespiti**           | `GRAPH MATCH` + `SHORTEST_PATH`    | [`/fraud`](docs/04-senaryo-fraud-ring.md)            |
| 4 | **Bunu alanlar bunu da aldı**    | `GRAPH MATCH` 2-hop                | [`/urun/{id}`](docs/05-senaryo-co-purchase.md)       |

---

## Mimari

<p align="center">
  <img src="docs/assets/architecture.svg" alt="DMCShop architecture" width="100%" />
</p>

Üç katman, tek VM (Azure B4ms westeurope · 4 vCPU / 16 GB RAM). Local docker-compose ile **aynı stack**.

### Senaryo 2 — RAG asistanı akışı

```mermaid
sequenceDiagram
    autonumber
    participant U as Tarayıcı (/asistan)
    participant W as Blazor Server
    participant E as IEmbeddingProvider (Ollama)
    participant V as vector.product_embedding (DiskANN)
    participant S as shop.product
    participant C as IChatProvider (Ollama qwen2.5:3b)
    participant L as vector.query_log

    U->>W: "1500 TL altı ergonomik mouse"
    W->>E: EmbedAsync(soru)
    E-->>W: float[768]
    W->>V: VECTOR_SEARCH TOP_N=5 (cosine)
    V-->>W: top-K product_id
    W->>S: JOIN ile ürün detayları
    S-->>W: ProductHit[]
    W-->>U: durum: "retrieval bitti"
    W->>C: StreamAsync(system, bağlam + soru)
    loop her token
        C-->>W: chunk
        W-->>U: SignalR ile UI'a token
    end
    W->>L: INSERT query_log (provider, latency, used_ids)
```

### Senaryo 3 — Fraud ring tespiti

```mermaid
flowchart LR
    A[shop.customer_device] -- aynı device --> P1[shared_device]
    B[shop.device.ip_address] -- aynı IP --> P2[shared_ip]
    C[shop.payment_method.card_fingerprint] -- aynı kart --> P3[shared_card]
    P1 --> U[UNION ALL]
    P2 --> U
    P3 --> U
    U --> R{Risk = CASE müşteri sayısı}
    R --> H[HIGH: 4+ paylaşan]
    R --> M[MEDIUM: 2-3 paylaşan]
    H --> UI[/fraud sayfası: server-side pagination + arama + sıralama/]
    M --> UI
```

### Senaryo 4 — Co-purchase 2-hop

```mermaid
flowchart LR
    P1((Ürün p1)) <-.purchased.- C((Müşteri))
    C -.purchased.-> P2((Ürün p2))
    P1 -- MATCH p1 ← purchased ← c → purchased → p2 --> Q[Sıralı sonuç]
    Q --> UI[/urun/&#123;id&#125; · Bunu alanlar bunu da aldı/]
```

---

## Hızlı başlangıç

### Local — Docker Compose

Önkoşullar: Docker · .NET 10 SDK · `sqlcmd` (`brew install sqlcmd`).

```bash
git clone https://github.com/dmcteknoloji/dmcshop-sql2025.git
cd dmcshop-sql2025

docker compose -f scripts/docker-compose.yml up -d
docker exec dmcshop-ollama ollama pull nomic-embed-text
docker exec dmcshop-ollama ollama pull qwen2.5:3b-instruct-q4_K_M
./scripts/bootstrap.sh                                       # schema + 120 showcase ürün
dotnet run --project app/src/DMCShop.Cli -- embed-products   # vector embedding üret
dotnet run --project app/src/DMCShop.Web                     # http://localhost:5295
```

Kurumsal ölçek (50K ürün) için ek adım:
```bash
sqlcmd -C -I -S localhost -U sa -P 'dmcShop_2026!Demo' -d dmcshop \
    -i sql/30-seed-large.sql -i sql/31-seed-large-customers.sql \
    -i sql/32-seed-large-orders.sql -i sql/33-seed-large-graph.sql
```

### Azure — Bicep + cloud-init

```bash
az login
./infra/deploy.sh                  # tek komutla: RG + VM + cloud-init + rsync + bootstrap + embed
```

Detay: [infra/README.md](infra/README.md). `./infra/sync.sh` ile sonraki güncellemeler, `./infra/teardown.sh` ile tek komutla siler.

---

## Proje yapısı

```
dmcshop-sql2025/
├── sql/                          # SQL Server 2025 betikleri (tek truth source)
│   ├── 00-database-create.sql    # PREVIEW_FEATURES = ON, schema
│   ├── 01-04                     # shop · graph · vector · ops schema'ları
│   ├── 05-07                     # showcase seed (120 ürün)
│   ├── 08-create-vector-indexes  # DiskANN (embed sonrası)
│   ├── 10-11                     # ops.sp_embed_text · ops.sp_chat_complete
│   ├── 20-23                     # 4 senaryo T-SQL örnekleri
│   └── 30-33                     # kurumsal ölçek seed (50K ürün, 10K müşteri)
├── app/                          # .NET 10 solution
│   └── src/
│       ├── DMCShop.Domain        # entity + abstraction (DB-agnostic)
│       ├── DMCShop.Data          # EF Core 10 DbContext + configurations
│       ├── DMCShop.Providers     # OpenAI ve Ollama adapter'leri (embed + chat + streaming)
│       ├── DMCShop.Search        # VectorSearch · GraphRecommend · RagAssistant · FraudRing
│       ├── DMCShop.Api           # Minimal API (planlı)
│       ├── DMCShop.Web           # Blazor Server — 5 sayfa
│       └── DMCShop.Cli           # dmcshop CLI: seed, embed-products, health
├── infra/                        # Azure deployment
│   ├── main.bicep                # VM + VNet + NSG + Public IP
│   ├── cloud-init.yaml           # Docker + .NET 10 + sqlcmd + systemd unit
│   ├── deploy.sh                 # ilk kurulum
│   ├── sync.sh                   # sonraki güncellemeler
│   └── teardown.sh               # az group delete
├── scripts/
│   ├── docker-compose.yml        # SQL Server 2025 + Ollama (restart: unless-stopped)
│   └── bootstrap.sh              # sqlcmd ile sql/ dosyalarını sırayla çalıştırır
└── docs/                         # senaryo dökümanları + assets
```

---

## Yol haritası

| Milestone                          | Durum    | Tarih       |
| ---------------------------------- | -------- | ----------- |
| M1 — Skeleton (repo + schema + .NET solution) | ✓ Tamam | 2026-05-17 |
| M2 — Senaryo 1 + 4 (semantik arama + co-purchase) | ✓ Tamam | 2026-05-17 |
| UI iterasyonları (FluentUI → açık tema e-ticaret) | ✓ Tamam | 2026-05-17 |
| Azure VM deployment (Bicep + cloud-init) | ✓ Tamam | 2026-05-17 |
| M3 — Senaryo 2 + 3 (RAG + fraud) | ✓ Tamam | 2026-05-17 |
| Kurumsal ölçek (50K ürün)         | ✓ Tamam | 2026-05-18 |
| Streaming RAG + server-side pagination | ✓ Tamam | 2026-05-18 |
| HTTPS + custom domain             | Planlı  | —           |
| Container Apps autoscale (refaktör) | Planlı  | —           |
| GitHub Actions CI/CD              | Planlı  | —           |

---

## SQL Server 2025 RTM-CU4 yakalanan nüanslar

Workshop için kayda değer üç davranış:

1. **VECTOR tipi preview bayrağıyla açılır.** Database scoped configuration:
   ```sql
   ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
   ```
2. **DiskANN vector index varken tabloya hiçbir DML yapılamaz** (`Msg 42231` — INSERT, UPDATE
   ve DELETE hepsi reddedilir). Tek yol: önce `DROP INDEX`, sonra DML, sonra yeniden `CREATE
   VECTOR INDEX`. CLI `embed-products` bunu otomatik yönetir; manuel toplu yükleme için
   `sql/08-create-vector-indexes.sql` ayrı dosyadır.
3. **`VECTOR_SEARCH` sözdizimi.** Eski `TOP (N) WITH APPROXIMATE` RTM'de yok; yerine:
   ```sql
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
   Dış JOIN için VECTOR_SEARCH çıktısı CTE içinde tutulmalı.

---

## Lisans ve iletişim

[MIT](LICENSE) · © 2026 [Çağlar Özenç](https://www.linkedin.com/in/caglarozenc) & [DMC Bilgi Teknolojileri](https://dmcteknoloji.com)

Kitap: **SQL Server 2025: Herkes İçin, Her Rol İçin** — [dmcteknoloji/sql-server-2025-kitap](https://github.com/dmcteknoloji/sql-server-2025-kitap)
İletişim: `iletisim@dmcteknoloji.com`
