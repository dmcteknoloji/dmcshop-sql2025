# Changelog

Bu projenin tüm önemli değişiklikleri burada izlenir. Format [Keep a Changelog](https://keepachangelog.com/) standardına göredir.

## [Unreleased]

### Eklendi (2026-05-18, açık konular kapatma paketi)
- **Senaryo 5 — Vector + Graph hibrit**: PersonalizedRecommendService (.NET'te
  centroid → VECTOR_SEARCH → graph social subquery → hibrit skor), /bana-ozel
  Blazor sayfası, sql/24-personalized.sql
- **External model setup**: sql/12-create-external-model.sql + setup.sh
  sp_configure 'external rest endpoint enabled' = 1 otomasyonu. T-SQL'den
  AI_GENERATE_EMBEDDINGS çağrıları artık çalışır
- **Streaming RAG**: IChatProvider.StreamAsync; OllamaChatProvider line-delimited
  JSON parse, OpenAIChatProvider CompleteChatStreamingAsync; Assistant.razor
  durum göstergesi (retrieval → streaming → done) + token-token render
- **Chat history kalıcı**: RagAssistantService.HistoryAsync — vector.query_log
  son 8 sorgu; /asistan açılışında geçmiş kart listesi
- **Mobile responsive**: @media query 900px ve 560px breakpoint'ler;
  toolbar dropdown'ları stack, catalog sidebar üstte, header nav scroll
- **RAG prompt güçlendirme**: SystemPrompt 6 madde, "yalnızca Türkçe, garip
  karakter kombinasyonu yazma" talimatı (qwen2.5:3b artifact'ları için)
- **Retention**: sql/40-retention.sql + ops.sp_purge_logs proc, cron talimatı
- **Smoke tests**: 21 xUnit testi (HybridScore, VectorLiteral, Centroid,
  Monogram), 46ms'de geçiyor
- **scripts/vm-schedule.sh**: az vm start/stop helper, GitHub Actions cron örneği
- **scripts/backup.sh**: BACKUP DATABASE → /backups, rotation 7gün, cron talimatı
- **infra/security-hardening.md**: NSG daraltma, Key Vault, TLS, log retention,
  scheduled stop, backup, container security, audit
- **infra/caddy/**: Caddyfile + docker-compose + README (Let's Encrypt veya
  self-signed)
- **.env.example**: tüm ortam değişkenleri tek dosyada şablon

### Düzeltildi (2026-05-18)
- **Fraud sayfası 500**: EF Core 10 SqlQueryRaw + CTE/OFFSET "non-composable
  composition" hatası → FraudRingService ADO.NET (Microsoft.Data.SqlClient)
  ile yeniden yazıldı
- **VM B2ms → B4ms**: Kurumsal seed + Ollama chat modeli 8 GB RAM'de OOM
  yapıyordu, 16 GB / 4 vCPU'ya yükseltildi
- **CREATE VECTOR INDEX timeout**: EF Core default 30sn timeout 50K vector
  build için yetmiyor; sqlcmd -t 600 ile manuel

### Eklendi (Azure deployment — VM + Bicep)
- `infra/main.bicep`: Tek VM (B2ms Ubuntu 24.04) + VNet + NSG + Public IP. Bicep lint temiz
- `infra/cloud-init.yaml`: Docker + .NET 10 SDK + sqlcmd + dmcshop-web systemd unit
- `infra/deploy.sh`: RG + Bicep + cloud-init bekleme + rsync repo + remote bootstrap + embed-products + systemctl
- `infra/sync.sh`: Sonraki kod güncellemeleri için rsync + build + restart
- `infra/teardown.sh`: `az group delete --yes --no-wait`
- README ana sayfada Azure quickstart

### Düzeltildi (RTM-CU4 syntax)
- `ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON` — VECTOR tipi için şart (00-database-create.sql)
- DiskANN index'leri 03-schema'dan çıkarıldı; embed-products CLI komutu son adımda CREATE INDEX yapar (Msg 42231 — DiskANN varken DML yasak)
- VECTOR_SEARCH için `TOP_N` parametre + CTE pattern (`TOP (N) WITH APPROXIMATE` RTM'de yok)
- bootstrap.sh `-I` flag (QUOTED_IDENTIFIER) — filtered index için
- 08-create-vector-indexes.sql: manuel index kurulumu için ayrı dosya

### Eklendi (Milestone 2 — semantic search + co-purchase)
- Seed verisi: 120 ürün, 50 müşteri, 80 device, 400 sipariş, 4 fraud ring tasarımı (sql/05-07)
- T-SQL senaryolar: 20-vector-search.sql ve 23-graph-co-purchase.sql (AI_GENERATE_EMBEDDINGS + DiskANN + MATCH 2-hop)
- DMCShop.Domain: 9 entity, IEmbeddingProvider/IChatProvider, ProductHit/CoPurchaseRow DTO'ları
- DMCShop.Data: DbContext + 9 IEntityTypeConfiguration; vector kolonları raw SQL ile yönetilir
- DMCShop.Providers: OpenAIEmbeddingProvider/Chat ve OllamaEmbeddingProvider/Chat; switchable DI
- DMCShop.Search: VectorSearchService (VECTOR_SEARCH + DiskANN) ve GraphRecommendService (co-purchase 2-hop)
- DMCShop.Web: /search (vector + LIKE yan yana) ve /urun/{id} (co-purchase önerileri) Blazor sayfaları
- DMCShop.Cli: dmcshop health ve dmcshop embed-products komutları
- bootstrap.sh seed dosyalarını da çalıştırır

### Eklendi (Milestone 1 — skeleton)
- Repo iskeleti: README, LICENSE (MIT), .gitignore, .editorconfig, global.json
- Directory.Build.props ve Directory.Packages.props (CPM)
- SQL schema: `shop`, `graph`, `vector`, `ops` (sql/00-04)
- .NET 10 solution + 7 src projesi (Domain, Data, Providers, Search, Api, Web, Cli) + 2 test projesi
- Docker compose: SQL Server 2025 + Ollama
- Bootstrap script: sqlcmd ile sql/ dosyalarını sırayla çalıştırır

## Roadmap

- **Milestone 2**: Senaryo 1 (semantic search) + Senaryo 4 (co-purchase) end-to-end
- **Milestone 3**: Senaryo 2 (RAG) + Senaryo 3 (fraud ring) + workshop akışı dökümanları
