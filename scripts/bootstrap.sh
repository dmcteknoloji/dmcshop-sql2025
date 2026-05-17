#!/usr/bin/env bash
# ============================================================================
# bootstrap.sh
# dmcshop veritabanını sıfırdan kurar. Idempotent: tekrar çalıştırıldığında
# 00 IF NOT EXISTS, 01-04 ise DROP CASCADE gerektirir; mevcut demo için
# 99-teardown.sql'i ayrı çalıştırmak daha temizdir.
#
# Önkoşul:
#   - docker compose -f scripts/docker-compose.yml up -d
#   - sqlcmd (mssql-tools18 veya go-sqlcmd) PATH'te.
#
# Ortam değişkenleri:
#   DMCSHOP_SA_PASSWORD  (varsayılan: dmcShop_2026!Demo)
#   DMCSHOP_HOST         (varsayılan: localhost,1433)
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SQL_DIR="${REPO_ROOT}/sql"

HOST="${DMCSHOP_HOST:-localhost,1433}"
PASSWORD="${DMCSHOP_SA_PASSWORD:-dmcShop_2026!Demo}"

if ! command -v sqlcmd >/dev/null 2>&1; then
    echo "HATA: sqlcmd bulunamadı. mssql-tools18 veya go-sqlcmd kurun." >&2
    echo "       brew install sqlcmd" >&2
    exit 1
fi

echo "> dmcshop bootstrap başlıyor."
echo "  host:    ${HOST}"
echo "  sql:     ${SQL_DIR}"

# Bağlantı kontrolü
if ! sqlcmd -C -S "${HOST}" -U sa -P "${PASSWORD}" -Q "SELECT @@VERSION" -h -1 >/dev/null 2>&1; then
    echo "HATA: SQL Server'a bağlanılamadı. docker compose ayakta mı?" >&2
    exit 2
fi

# Sırayla çalıştır
for script in \
    "00-database-create.sql" \
    "01-schema-shop.sql" \
    "02-schema-graph.sql" \
    "03-schema-vector.sql" \
    "04-schema-ops.sql"
do
    path="${SQL_DIR}/${script}"
    if [[ ! -f "${path}" ]]; then
        echo "HATA: ${path} bulunamadı." >&2
        exit 3
    fi
    echo "> ${script}"
    sqlcmd -C -S "${HOST}" -U sa -P "${PASSWORD}" -d master -i "${path}" -b
done

# Doğrulama
echo "> Doğrulama: tablo sayısı"
sqlcmd -C -S "${HOST}" -U sa -P "${PASSWORD}" -d dmcshop -h -1 -W -Q "
SET NOCOUNT ON;
SELECT TABLE_SCHEMA AS schema_name, COUNT(*) AS table_count
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
  AND TABLE_SCHEMA IN ('shop', 'graph', 'vector', 'ops')
GROUP BY TABLE_SCHEMA
ORDER BY schema_name;"

echo "> Bootstrap tamam. Sonraki adım: dotnet run --project app/src/DMCShop.Web"
