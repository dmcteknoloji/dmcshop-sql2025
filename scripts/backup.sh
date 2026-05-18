#!/usr/bin/env bash
# ============================================================================
# scripts/backup.sh
# dmcshop veritabanını .bak dosyasına yedekler. VM üzerinde çalışmak içindir;
# /backups klasörüne yazar (volume mount'lu olmalı veya disk var).
# Rotation: 7 günden eski .bak dosyaları silinir.
#
# Cron: 0 2 * * *  /home/dmcshop/dmcshop-sql2025/scripts/backup.sh
# ============================================================================

set -euo pipefail

: "${DMCSHOP_SA_PASSWORD:=dmcShop_2026!Demo}"
: "${BACKUP_DIR:=/backups}"
: "${RETAIN_DAYS:=7}"

mkdir -p "${BACKUP_DIR}"

STAMP="$(date -u +%Y%m%d_%H%M%S)"
BAK_FILE="${BACKUP_DIR}/dmcshop_${STAMP}.bak"

echo "==> Backup: ${BAK_FILE}"

# SQL Server container içinde mssql-tools18 var; sqlcmd ile BACKUP DATABASE
# Backup file'ı container'ın görebileceği bir yola yaz (volume mount).
# Burada VM filesystem yolu ↔ container yolu eşleşmesi gerekiyor:
docker exec dmcshop-mssql /opt/mssql-tools18/bin/sqlcmd \
    -C -S localhost -U sa -P "${DMCSHOP_SA_PASSWORD}" -Q "
BACKUP DATABASE dmcshop
TO DISK = '/var/opt/mssql/backup/dmcshop_${STAMP}.bak'
WITH FORMAT, INIT, COMPRESSION, STATS = 10;
"

# Container'dan VM filesystem'e kopyala
docker cp "dmcshop-mssql:/var/opt/mssql/backup/dmcshop_${STAMP}.bak" "${BAK_FILE}"
docker exec dmcshop-mssql rm "/var/opt/mssql/backup/dmcshop_${STAMP}.bak" 2>/dev/null || true

echo "==> Boyut: $(du -h "${BAK_FILE}" | cut -f1)"

echo "==> Rotation: ${RETAIN_DAYS} günden eski yedekler siliniyor"
find "${BACKUP_DIR}" -name 'dmcshop_*.bak' -mtime "+${RETAIN_DAYS}" -delete

echo "==> Backup tamam"
ls -lh "${BACKUP_DIR}" | tail -5
