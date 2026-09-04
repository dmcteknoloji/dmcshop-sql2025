#!/usr/bin/env bash
# ============================================================================
# scripts/setup.sh
# DMCShop local ortamını sıfırdan ayağa kaldırır. Idempotent — yeniden
# çalıştırılabilir; sadece eksik adımları yapar.
#
# Akış:
#   1) docker compose up (mssql + ollama)
#   2) ollama'ya bge-m3 + qwen2.5:3b indir
#   3) bootstrap.sh (schema + showcase 120 ürün seed)
#   4) DMCSHOP_SCALE=large ise: sql/30-33 (50K ürün, 10K müşteri, 100K sipariş)
#   5) vector index drop → embedding üret → uzun-timeout ile index yeniden oluştur
#   6) Blazor uygulamasını hazır bırak (manuel başlatma)
#
# Kullanım:
#   ./scripts/setup.sh                            # showcase (120 ürün, ~3 dakika)
#   DMCSHOP_SCALE=large ./scripts/setup.sh        # kurumsal (50K ürün, ~45 dakika)
#
# Önkoşullar:
#   - Docker Desktop / Docker Engine
#   - .NET 10 SDK
#   - sqlcmd (mac: brew install sqlcmd; linux: mssql-tools18)
# ============================================================================

set -euo pipefail

# SA parolasi: ortam -> scripts/.env -> rastgele uret (varsayilan parola YOK).
# ConnectionStrings__DMCShop da burada export edilir.
# shellcheck source=scripts/sa-password.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sa-password.sh"

# ---- ayarlar (env ile override edilebilir) ---------------------------------
: "${DMCSHOP_SCALE:=showcase}"           # showcase | large
# 127.0.0.1: konteyner portu IPv4 loopback'e bagli, `localhost` ::1 olabilir.
: "${DMCSHOP_HOST:=127.0.0.1,1433}"
: "${OLLAMA_EMBED_MODEL:=bge-m3}"
: "${OLLAMA_CHAT_MODEL:=qwen2.5:3b-instruct-q4_K_M}"
: "${EMBED_BATCH:=32}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SQL_DIR="${REPO_ROOT}/sql"

# ---- yardımcılar -----------------------------------------------------------
say()  { printf '\n\033[1;35m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m![]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mHATA\033[0m %s\n' "$*" >&2; exit 1; }

sqlexec() {
    local query="$1"
    local timeout="${2:-30}"
    sqlcmd -C -I -t "${timeout}" -S "${DMCSHOP_HOST}" -U sa -P "${DMCSHOP_SA_PASSWORD}" \
           -d dmcshop -b -Q "${query}"
}

count_embedded() {
    sqlcmd -C -I -S "${DMCSHOP_HOST}" -U sa -P "${DMCSHOP_SA_PASSWORD}" \
           -d dmcshop -h -1 -W -Q \
           "SELECT SUM(CASE WHEN embedding_bge_1024 IS NOT NULL THEN 1 ELSE 0 END) FROM vector.product_embedding" \
           | head -1 | tr -d ' '
}

# ---- önkoşul kontrolleri ---------------------------------------------------
say "Önkoşullar kontrol ediliyor"
command -v docker  >/dev/null || die "docker gerekli (Docker Desktop / Docker Engine)"
command -v dotnet  >/dev/null || die ".NET 10 SDK gerekli"
command -v sqlcmd  >/dev/null || die "sqlcmd gerekli (brew install sqlcmd / mssql-tools18)"

case "${DMCSHOP_SCALE}" in
    showcase|large) ;;
    *) die "DMCSHOP_SCALE 'showcase' veya 'large' olmalı (verilen: '${DMCSHOP_SCALE}')" ;;
esac

echo "  ölçek:    ${DMCSHOP_SCALE}"
echo "  host:     ${DMCSHOP_HOST}"
echo "  embed:    ${OLLAMA_EMBED_MODEL}"
echo "  chat:     ${OLLAMA_CHAT_MODEL}"

# ---- 1) docker compose up --------------------------------------------------
say "Docker container'ları kontrol ediliyor"
if ! docker ps --format '{{.Names}}' | grep -q '^dmcshop-mssql$'; then
    docker compose -f "${SCRIPT_DIR}/docker-compose.yml" up -d
else
    echo "  zaten ayakta"
fi

# SQL Server healthy bekleme
say "SQL Server healthy bekleniyor (~20-40 sn)"
for i in {1..30}; do
    if sqlcmd -C -I -S "${DMCSHOP_HOST}" -U sa -P "${DMCSHOP_SA_PASSWORD}" \
              -Q "SELECT 1" >/dev/null 2>&1; then
        echo "  hazır (${i}. denemede)"
        break
    fi
    sleep 3
    [[ $i -eq 30 ]] && die "SQL Server açılamadı"
done

# ---- 2) Ollama modelleri ---------------------------------------------------
say "Ollama modelleri kontrol ediliyor"
for model in "${OLLAMA_EMBED_MODEL}" "${OLLAMA_CHAT_MODEL}"; do
    if docker exec dmcshop-ollama ollama list 2>/dev/null | grep -q "${model%%:*}"; then
        echo "  ${model}: var"
    else
        echo "  ${model}: indiriliyor (chat modeli için ~2-3 GB)"
        docker exec dmcshop-ollama ollama pull "${model}"
    fi
done

# ---- 3a) External REST endpoint + external model -------------------------
say "External REST endpoint + EXTERNAL MODEL setup"
sqlcmd -C -I -S "${DMCSHOP_HOST}" -U sa -P "${DMCSHOP_SA_PASSWORD}" -d master -Q "
IF (SELECT value FROM sys.configurations WHERE name = 'external rest endpoint enabled') = 0
BEGIN
    EXEC sp_configure 'external rest endpoint enabled', 1;
    RECONFIGURE;
END" >/dev/null 2>&1 || warn "sp_configure başarısız (sysadmin gerekli)"

# ---- 3) Schema + showcase seed --------------------------------------------
say "Schema + showcase seed (bootstrap.sh)"
if sqlcmd -C -I -S "${DMCSHOP_HOST}" -U sa -P "${DMCSHOP_SA_PASSWORD}" \
          -d master -Q "SELECT name FROM sys.databases WHERE name = 'dmcshop'" -h -1 2>/dev/null \
          | grep -q dmcshop; then
    if [[ "$(sqlcmd -C -I -S "${DMCSHOP_HOST}" -U sa -P "${DMCSHOP_SA_PASSWORD}" \
              -d dmcshop -h -1 -W -Q "SELECT COUNT(*) FROM shop.product" 2>/dev/null \
              | head -1 | tr -d ' ')" != "0" ]]; then
        echo "  dmcshop zaten dolu, atlanıyor"
    else
        "${SCRIPT_DIR}/bootstrap.sh"
    fi
else
    "${SCRIPT_DIR}/bootstrap.sh"
fi

# ---- 4) Kurumsal ölçek (opsiyonel) ----------------------------------------
if [[ "${DMCSHOP_SCALE}" == "large" ]]; then
    say "Kurumsal ölçek seed (sql/30-33)"
    product_count="$(sqlcmd -C -I -S "${DMCSHOP_HOST}" -U sa -P "${DMCSHOP_SA_PASSWORD}" \
                       -d dmcshop -h -1 -W -Q "SELECT COUNT(*) FROM shop.product" \
                     | head -1 | tr -d ' ')"
    if [[ "${product_count}" -lt 10000 ]]; then
        for f in 30-seed-large.sql 31-seed-large-customers.sql \
                 32-seed-large-orders.sql 33-seed-large-graph.sql; do
            echo "  ${f}"
            sqlcmd -C -I -t 600 -S "${DMCSHOP_HOST}" -U sa -P "${DMCSHOP_SA_PASSWORD}" \
                   -d dmcshop -b -i "${SQL_DIR}/${f}" | tail -5
        done
    else
        echo "  zaten ${product_count} ürün var, atlanıyor"
    fi
fi

# ---- 5) Embedding üretimi -------------------------------------------------
# Vector.product_embedding satırları source_text dolu olmalı (eksik olanları ekle)
say "Eksik vector.product_embedding satırlarını ekle"
# DiskANN index varsa DML yasak — drop, INSERT, embed sonunda recreate
sqlexec "
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'vix_pe_bge')
    DROP INDEX vix_pe_bge ON vector.product_embedding;

INSERT INTO vector.product_embedding (product_id, source_text)
SELECT p.product_id, CONCAT(p.name, N'. ', c.name, N'. ', p.description_tr)
FROM   shop.product p
JOIN   shop.product_category c ON c.category_id = p.category_id
WHERE  NOT EXISTS (SELECT 1 FROM vector.product_embedding pe WHERE pe.product_id = p.product_id);

SELECT COUNT(*) AS satir FROM vector.product_embedding;
"

say "Embedding üretimi (Ollama bge-m3)"
before="$(count_embedded)"
echo "  başlangıç: ${before} embedded"
dotnet run --project "${REPO_ROOT}/app/src/DMCShop.Cli" -c Release -- \
    embed-products --only-missing --batch "${EMBED_BATCH}" 2>&1 | grep -E "^[0-9]+:" | tail -20 || true
after="$(count_embedded)"
echo "  bitiş:     ${after} embedded"

# ---- 6) DiskANN vector index ----------------------------------------------
# embed-products kendisi yarat-recreate yapsa da büyük setlerde EF Core
# command timeout (30 sn) yetmez. Burada -t 600 ile manuel.
say "DiskANN vector index (50K vector ~70 sn, 120 vector ~1 sn)"
sqlexec "
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'vix_pe_bge')
    DROP INDEX vix_pe_bge ON vector.product_embedding;

CREATE VECTOR INDEX vix_pe_bge
ON vector.product_embedding (embedding_bge_1024)
WITH (METRIC = 'cosine', TYPE = 'DiskANN', MAXDOP = 4);

SELECT name FROM sys.indexes WHERE object_id = OBJECT_ID('vector.product_embedding') AND type = 8;
" 600

# ---- 6.5) External model (T-SQL workshop için) ---------------------------
say "EXTERNAL MODEL tanımları (T-SQL'den AI_GENERATE_EMBEDDINGS için)"
sqlcmd -C -I -t 60 -S "${DMCSHOP_HOST}" -U sa -P "${DMCSHOP_SA_PASSWORD}" -d dmcshop \
       -i "${SQL_DIR}/12-create-external-model.sql" 2>&1 | tail -5 \
       || warn "External model setup başarısız (host.docker.internal erişilemiyor olabilir)"

# ---- 7) Özet --------------------------------------------------------------
say "Hazır"
sqlcmd -C -I -S "${DMCSHOP_HOST}" -U sa -P "${DMCSHOP_SA_PASSWORD}" -d dmcshop -h -1 -W -Q "
SELECT 'product' AS entity, COUNT(*) AS n FROM shop.product
UNION ALL SELECT 'customer',  COUNT(*) FROM shop.customer
UNION ALL SELECT 'order',     COUNT(*) FROM shop.[order]
UNION ALL SELECT 'embedded',  SUM(CASE WHEN embedding_bge_1024 IS NOT NULL THEN 1 ELSE 0 END) FROM vector.product_embedding;
"

cat <<EOF

Sonraki adım — Blazor uygulamasını başlat:

  dotnet run --project app/src/DMCShop.Web

Tarayıcı: http://localhost:5295

Sayfalar:
  /            anasayfa (dinamik sayım)
  /katalog     ürün kataloğu (pagination + kategori filtre)
  /search      semantik arama (vector vs LIKE karşılaştırma)
  /asistan     RAG asistan (streaming, ilk soru ~15 sn cold-start)
  /fraud       fraud ring tespiti
  /urun/{id}   ürün detay + co-purchase önerileri
EOF
