# Changelog

Bu projenin tüm önemli değişiklikleri burada izlenir. Format [Keep a Changelog](https://keepachangelog.com/) standardına göredir.

## [Unreleased]

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
