# Changelog

Bu projenin tüm önemli değişiklikleri burada izlenir. Format [Keep a Changelog](https://keepachangelog.com/) standardına göredir.

## [Unreleased]

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
