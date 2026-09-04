# Kendi ortamında çalıştırma

Bu kılavuz, DMCShop'u sıfırdan kurmak için iki yol gösterir: **local docker-compose** (yerel
makinen) ve **Azure VM** (uzak demo). İki yolda da sonuç: tarayıcıdan açılabilir, dört senaryosu
çalışır bir referans uygulama.

> İki yol için de **aynı tek komut** yeterli — `scripts/setup.sh` (local) veya
> `infra/deploy.sh` (Azure). Bu doküman manuel adımları ve sorun giderme yollarını anlatır.

---

## A — Local kurulum

### Önkoşullar

| Araç           | Kontrol                              | Mac kurulum                            |
| -------------- | ------------------------------------ | -------------------------------------- |
| Docker         | `docker --version`                   | Docker Desktop                         |
| .NET 10 SDK    | `dotnet --version` → `10.x`          | https://dotnet.microsoft.com/download  |
| sqlcmd         | `sqlcmd "-?"`                        | `brew install sqlcmd`                  |
| git            | `git --version`                      | Apple CLT                              |

### Tek komutla kurulum

```bash
git clone https://github.com/dmcteknoloji/dmcshop-sql2025.git
cd dmcshop-sql2025

./scripts/setup.sh                       # showcase (120 ürün, ~3 dakika)
# ya da
DMCSHOP_SCALE=large ./scripts/setup.sh   # kurumsal (50K ürün, ~45 dakika)
```

Setup script şunları yapar:

1. **docker compose up** — `dmcshop-mssql` (SQL Server 2025 CU8) + `dmcshop-ollama`
2. **Ollama modelleri** — `bge-m3` (~270 MB) + `qwen2.5:3b-instruct-q4_K_M` (~2 GB)
3. **Schema + showcase seed** — `bootstrap.sh` → 4 schema (`shop`, `graph`, `vector`, `ops`) + 120 ürün
4. **(opsiyonel) Kurumsal seed** — `sql/30-33`: 50K ürün + 10K müşteri + 100K sipariş + 451K satır
5. **Eksik vector satırı INSERT** — `vector.product_embedding` her ürün için source_text
6. **Embedding üretimi** — Ollama bge-m3 · batch 32 · paralel
7. **DiskANN vector index** — `CREATE VECTOR INDEX ... WITH (METRIC='cosine', TYPE='DiskANN')`

### Uygulamayı başlat

```bash
dotnet run --project app/src/DMCShop.Web
# tarayıcı: http://localhost:5295
```

### Sonraki çalıştırmalar

Setup idempotent. Tekrar çalıştırdığında:
- Container zaten ayaktaysa atlar
- Modeller varsa atlar
- DB doluysa schema/seed atlar
- Yeni eklenen ürünler için sadece eksik embedding'leri üretir (`--only-missing`)

---

## B — Azure VM kurulum

### Önkoşullar

- Azure subscription
- Azure CLI (`az login` yapılmış)
- `rsync`, `jq`

### Tek komutla deploy

```bash
./infra/deploy.sh
```

Yapacaklar:

1. `~/.ssh/dmcshop_ed25519` yoksa üretir
2. `rg-dmcshop-demo` Resource Group + Bicep deploy: VM (B4ms Ubuntu 24.04) + VNet + NSG + Public IP
3. cloud-init bitmesini bekler (~5-8 dk: docker + .NET 10 + sqlcmd kurulumu)
4. Repo'yu `rsync` ile VM'e gönderir
5. Remote: docker compose + bootstrap + embed-products + systemd

Sonunda public URL: `http://dmcshop-<hash>.<region>.cloudapp.azure.com`

Detay: [infra/README.md](../infra/README.md)

### Kurumsal seed Azure VM'de

`deploy.sh` showcase seed'i çalıştırır. Kurumsal scale için SSH ile:

```bash
ssh -i ~/.ssh/dmcshop_ed25519 dmcshop@<fqdn>
cd ~/dmcshop-sql2025
DMCSHOP_SCALE=large ./scripts/setup.sh
```

`dotnet run` ile değil, systemd unit `dmcshop-web.service` üzerinden çalışır.
`./infra/sync.sh` ile sonraki kod güncellemeleri.

---

## Senaryolar — ne çalışır

| Sayfa           | Senaryo                          | Ölçek                                          |
| --------------- | -------------------------------- | ---------------------------------------------- |
| `/`             | Dinamik dashboard                | DB sayımları (ürün, müşteri, sipariş, ...)     |
| `/katalog`      | Ürün ızgarası                    | Pagination + kategori filtre + arama + sıralama |
| `/search`       | Semantik arama                   | Vector + DiskANN; LIKE karşılaştırma           |
| `/asistan`      | RAG chat                         | Streaming token-by-token; query_log audit      |
| `/fraud`        | Fraud ring tespiti               | 3 pattern + risk + arama + sıralama            |
| `/urun/{id}`    | Ürün detay + co-purchase         | Graph MATCH 2-hop                              |

---

## Sorun giderme

### `Msg 42231: Data modification statement failed because table has a vector index on it`

**Sebep**: SQL Server 2025'te DiskANN vector index varken **hiçbir DML** (INSERT/UPDATE/DELETE)
yapılamıyor.

**Çözüm**: önce `DROP INDEX vix_pe_bge ON vector.product_embedding`, sonra DML, sonra
`CREATE VECTOR INDEX ... WITH (METRIC='cosine', TYPE='DiskANN')`. `scripts/setup.sh` bunu
otomatik yönetir.

### `Cannot find a vector index with metric 'cosine' on column 'embedding_bge_1024'`

**Sebep**: `VECTOR_SEARCH` cosine metriği olan bir DiskANN index istiyor; tabloda index yok.

**Çözüm**: `sql/08-create-vector-indexes.sql` çalıştır veya:
```sql
CREATE VECTOR INDEX vix_pe_bge
ON vector.product_embedding (embedding_bge_1024)
WITH (METRIC = 'cosine', TYPE = 'DiskANN', MAXDOP = 4);
```

50K vector için DiskANN build ~70 saniye sürer — sqlcmd default 30 sn timeout yetmez.
`sqlcmd -t 600` ile çalıştır.

### `model requires more system memory (X GiB) than is available (Y GiB)`

**Sebep**: Ollama chat modeli için yeterli RAM yok. B2ms (8 GB) llama3.1:8b için yetmez.

**Çözüm**: Daha küçük model — `qwen2.5:3b-instruct-q4_K_M` (~2 GB) veya VM'i B4ms'e (16 GB)
yükselt: `az vm resize -g rg-dmcshop-demo -n dmcshop-vm --size Standard_B4ms`

### Asistan ilk soruda 15-30 saniye bekliyor

**Sebep**: Ollama chat modeli RAM'e ilk kez yüklenir (cold-start). 8B model ~12 sn, 3B ~6 sn.

**Sonraki sorular**: model RAM'de cache'li, yanıt ~1-3 saniye + token üretim hızı.

### Docker container VM restart sonrası kalkmıyor

**Sebep**: docker-compose.yml'de `restart: unless-stopped` policy yok.

**Çözüm**: Mevcut compose dosyasında ekli, ama mevcut canlı container için:
```bash
docker update --restart unless-stopped dmcshop-mssql dmcshop-ollama
```

### Embedding üretimi çok yavaş

- Ollama default `OLLAMA_NUM_PARALLEL=4` — daha fazla için `docker exec dmcshop-ollama` ortamına env
- `--batch 64` ile daha büyük batch (RAM yeterli olmalı)
- B4ms 4 vCPU üzerinde ~1.000 ürün/dakika beklenir
- Cold-start sırasında model yüklenir, ilk ~100 ürün yavaş olabilir

---

## Sıfırla

```bash
docker compose -f scripts/docker-compose.yml down -v   # container + volume sil
rm -rf ~/.ollama                                       # local'de ollama model cache (opsiyonel)
./scripts/setup.sh                                     # baştan başlat
```

Azure VM'de:
```bash
./infra/teardown.sh   # az group delete --yes --no-wait
```

---

## Sonraki adım

İlk kez çalıştırdıysan, [docs/06-workshop-akisi.md](06-workshop-akisi.md) kapsamlı bir
60-90 dakikalık senaryo turunu öneriyor (yakında).
