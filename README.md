# DMCShop — SQL Server 2025 Graph + AI Demo

**SQL Server 2025: Herkes İçin, Her Rol İçin** kitabının okurları için referans demo projesi. Klasik bir e-ticaret iskeleti üzerinde SQL Server 2025'in iki amiral özelliği canlandırılır: `VECTOR(N) + DiskANN` ve `GRAPH NODE/EDGE + SHORTEST_PATH`.

## Senaryolar

| # | Senaryo | Özellik | T-SQL | Blazor |
|---|---|---|---|---|
| 1 | Semantic product search | VECTOR + DiskANN | `sql/20-vector-search.sql` | `/search` |
| 2 | RAG ürün asistanı | Vector retrieval + LLM | `sql/21-rag-assistant.sql` | `/asistan` |
| 3 | Fraud ring detection | GRAPH + SHORTEST_PATH | `sql/22-fraud-ring.sql` | `/fraud` |
| 4 | Bunu alanlar bunu da aldı | GRAPH 2-hop | `sql/23-graph-co-purchase.sql` | `/urun/{id}` |

Embedding/chat provider **switchable**: Azure OpenAI (text-embedding-3-small, 1536 dim) veya local Ollama (nomic-embed-text, 768 dim). Hem T-SQL hem .NET tarafı `ops.provider_config` üzerinden aynı provider'ı kullanır.

## 5 dakikada başla

Önkoşullar: Docker, .NET 10 SDK, `sqlcmd`.

```bash
git clone https://github.com/dmcteknoloji/dmcshop-sql2025.git
cd dmcshop-sql2025

docker compose -f scripts/docker-compose.yml up -d
./scripts/bootstrap.sh
dotnet run --project app/src/DMCShop.Web
```

Tarayıcıda `https://localhost:5001` açılır.

## Mimari

- `sql/` — tek truth: schema, seed, stored procedure'ler, senaryo örnekleri. Sıralı dosyalar.
- `seed-data/` — 120 ürün, 50 müşteri, 400 sipariş, pre-computed embedding'ler (offline workshop için).
- `app/` — Blazor Server (.NET 10) + EF Core 10 + iki provider (Azure OpenAI / Ollama). Vector / graph işlemleri raw SQL (kitap bölüm 23 ve 02 pattern'leri).
- `docs/` — senaryo dökümanları ve 60-90 dk workshop akışı.

Detay: [docs/01-mimari-genel.md](docs/01-mimari-genel.md)

## Workshop akışı

[docs/06-workshop-akisi.md](docs/06-workshop-akisi.md) içinde 60-90 dakikalık bir oturum için bölüm bölüm akış var.

## Lisans

MIT. Detaylar [LICENSE](LICENSE).

(c) 2026 Çağlar Özenç & DMC Bilgi Teknolojileri
