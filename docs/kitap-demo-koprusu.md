# Kitap × Demo köprüsü

**SQL Server 2025: Herkes İçin, Her Rol İçin** kitabının 32 bölümünden hangisinin
DMCShop'ta hangi sayfa, T-SQL dosyası veya .NET kodu ile karşılandığını gösterir.
Kitabı okurken yan ekranda demo'yu açın, bölüm bittiğinde **canlı çalışan karşılığı**
göreceksiniz.

<p align="center">
  <a href="https://demo.dmcteknoloji.com">
    <img src="assets/demo-qr.svg" alt="https://demo.dmcteknoloji.com" width="240" />
  </a>
  <br/>
  <a href="https://demo.dmcteknoloji.com"><code>https://demo.dmcteknoloji.com</code></a>
</p>

---

## Roller × öğrenme rotası

### DBA rotası (Kısım I + II)
Veri tabanı yönetimi odaklı. DMCShop demosu ağırlıklı olarak Kısım V (AI/Mimari) ve
Kısım III (Geliştirici) gösterir; ama DBA bölümlerinin altyapısı **zaten her sayfada
çalışıyor**:

| Kitap bölümü | DMCShop'ta nerede |
|---|---|
| **Bölüm 4 — Kurulum (Docker)** | `scripts/docker-compose.yml` — SQL Server 2025 CU8 container |
| **Bölüm 6 — Optimized Locking** | DMCShop'un `shop.[order]` + `order_line` yazma yolları locking kontrastını gösterir (Workshop: SSMS sp_whoisactive ile gözlemle) |
| **Bölüm 10 — Query Store v3** | `ALTER DATABASE dmcshop SET QUERY_STORE = ON` (`sql/00-database-create.sql`); `/admin/perf` sayfası (roadmap) |

### Geliştirici rotası (Kısım III)

| Kitap bölümü | DMCShop'ta nerede |
|---|---|
| **Bölüm 12 — Modern T-SQL (JSON, regex)** | `vector.query_log.used_product_ids` JSON kolonu; `sql/22-fraud-ring.sql` `STRING_AGG ... WITHIN GROUP (GRAPH PATH)` |
| **Bölüm 13 — sp_invoke_external_rest_endpoint** | `sql/10-sp-embed.sql` + `sql/11-sp-chat.sql` Ollama/Azure OpenAI REST çağrıları |
| **Bölüm 15 — EF Core 9 + sürücüler** | `app/src/DMCShop.Data/DMCShopDbContext.cs` + 10 entity configuration; vector kolonlarının neden raw SQL ile yönetildiği |

### AI / Mimari rotası (Kısım V — DMCShop'un kalbi)

| Kitap bölümü | DMCShop'ta nerede |
|---|---|
| **Bölüm 21 — VECTOR(N) + DiskANN** | `sql/03-schema-vector.sql` + `sql/08-create-vector-indexes.sql` (CREATE VECTOR INDEX … METRIC='cosine', TYPE='DiskANN') |
| **Bölüm 22 — AI_GENERATE_EMBEDDINGS** | `sql/12-create-external-model.sql` (CREATE EXTERNAL MODEL ollama_embed_text / ollama_chat_qwen) + `sql/21-rag-assistant.sql` |
| **Bölüm 23 — VECTOR_SEARCH + BM25 hibrit** | `sql/20-vector-search.sql` (VECTOR_SEARCH … TOP_N + CTE pattern); `/search` sayfası vector vs LIKE yan yana |
| **Bölüm 24 — RAG uçtan uca** | `sql/21-rag-assistant.sql` (embed → search → chat → audit log); `/asistan` sayfası streaming token-by-token render |
| **Bölüm 26 — SQL MCP Server** | Henüz demoda yok — yol haritasında. Mevcut `ops.sp_embed_text` ile DAB style endpoint hazır |

### Veri / Türkiye rotası (Kısım IV + VI)

| Kitap bölümü | DMCShop'ta nerede |
|---|---|
| **Bölüm 19 — Change Event Streaming** | Yol haritasında: real-time fraud check trigger |
| **Bölüm 29 — Türkçe AI ekosistem** | `qwen2.5:3b-instruct` chat modeli (Kumru/BGE-M3'e geçiş kolay); ürün description'ları Türkçe; SystemPrompt Türkçe yanıt zorunlu |

---

## Senaryo bazlı eşleşme

DMCShop'un 5 senaryosunun her birinin **hangi kitap bölümleriyle birebir konuştuğu**:

### `/search` — Semantik arama
**İlgili bölümler**: 21 (VECTOR), 22 (AI_GENERATE_EMBEDDINGS), 23 (VECTOR_SEARCH), 29 (Türkçe)

Demo'da gözle göreceğiniz:
- VECTOR(1024) kolonunda saklanan `bge-m3` çıktısı
- DiskANN approximate kNN — `TOP_N = 5` parametre, CTE wrap (CU8'de de geçerli, kitap bölüm 23 erratası olarak not edildi)
- Aynı sorgu LIKE ile yan panelde — anlamsal vs lexical kontrast

### `/asistan` — RAG asistan
**İlgili bölümler**: 22 (embed), 23 (retrieval), 24 (RAG uçtan uca), 29 (Türkçe LLM)

Demo'da:
- `VectorSearchService` ile top-K retrieval → `IChatProvider.StreamAsync` token-token
- `vector.query_log` audit trail (her çağrı kayıt altında)
- Streaming UI: pulse animasyonlu durum göstergesi

### `/fraud` — Fraud ring tespiti
**İlgili bölümler**: 2 (Graph), 12 (STRING_AGG, JSON)

Demo'da:
- `graph.customer_node` + `graph.purchased`/`uses_device`/`uses_ip` NODE/EDGE
- 3 pattern UNION (cihaz/IP/kart paylaşımı)
- `sql/22-fraud-ring.sql` içinde `SHORTEST_PATH` evidence chain

### `/urun/{id}` — Co-purchase
**İlgili bölümler**: 2 (Graph MATCH 2-hop)

Demo'da:
- `MATCH(p1<-(purchased)-c-(purchased)->p2)` — graph dili, tek SELECT

### `/bana-ozel` — Vector + Graph hibrit
**İlgili bölümler**: 2 + 21 + 23 (üç bölüm birlikte)

Demo'da:
- .NET'te vector centroid hesabı (VECTOR AVG aggregate'i public yok; CU8'de de yok, Msg 8117)
- `VECTOR_SEARCH` + `graph.purchased` social proof subquery
- Hibrit skor = `distance + 1/(1+social)`

---

## Demo'da olmayan kitap konuları (kapsam dışı, ileride)

- Always On / DAG (Bölüm 8) — tek VM, replikasyon yok
- Fabric Mirroring (Bölüm 18) — yol haritasında, [reference-github-ornekler](../README.md#yol-haritası)
- Change Event Streaming → Fabric Eventstream (Bölüm 19) — real-time fraud için planlı
- SQL MCP Server (Bölüm 26) — sırasında, AI agent demo için en uygun aday
- KVKK / EU AI Act compliance (Bölüm 28) — audit log var ama PII masking yok

---

## Kitap repo bağlantısı

Kitap kaynak kodu: [`dmcteknoloji/sql-server-2025-kitap`](https://github.com/dmcteknoloji/sql-server-2025-kitap) — her bölümün `kod-ornekleri/bolum-XX/` klasörü altında SQL örnekleri. DMCShop bu örneklerin **canlı çalışan, e-ticaret bağlamında birleştirilmiş** versiyonu.

Workshop akışı: önce kitabı oku, sonra demo'yu aç ve aynı T-SQL parçalarını [`sql/`](../sql/) klasöründe gör. Eşleşmeler:

| Kitap kod örneği | DMCShop'taki karşılığı |
|---|---|
| `bolum-02/02-graph-mini-ornek.sql` | `sql/02-schema-graph.sql` + `sql/22-fraud-ring.sql` |
| `bolum-13/04-openai-api-cagri.sql` | `sql/10-sp-embed.sql` |
| `bolum-21/01-vector-tipi-temel.sql` | `sql/03-schema-vector.sql` |
| `bolum-21/03-diskann-index.sql` | `sql/08-create-vector-indexes.sql` |
| `bolum-22/02-external-model-ollama.sql` | `sql/12-create-external-model.sql` |
| `bolum-23/01-vector-search-temel.sql` | `sql/20-vector-search.sql` |
| `bolum-24/03-retrieval-llm.sql` | `sql/21-rag-assistant.sql` |
