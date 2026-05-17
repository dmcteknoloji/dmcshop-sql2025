#!/usr/bin/env bash
# ============================================================================
# infra/sync.sh
# Mevcut Azure VM'sine kod değişikliklerini gönderir, Release publish yapar,
# systemd servisini restart eder. İdempotent.
# ============================================================================

set -euo pipefail

: "${DMCSHOP_RG:=rg-dmcshop-demo}"
: "${DMCSHOP_NAME_PREFIX:=dmcshop}"
: "${DMCSHOP_SSH_KEY:=$HOME/.ssh/dmcshop_ed25519}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FQDN="$(az network public-ip show -g "${DMCSHOP_RG}" -n "${DMCSHOP_NAME_PREFIX}-pip" --query dnsSettings.fqdn -o tsv)"
USER="dmcshop"
SSH_OPTS=(-i "${DMCSHOP_SSH_KEY}" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)

echo "==> rsync ${FQDN}"
rsync -azh --delete \
    --exclude '.git/' --exclude 'app/**/bin/' --exclude 'app/**/obj/' \
    --exclude '.vs/' --exclude 'appsettings.Local.json' \
    -e "ssh ${SSH_OPTS[*]}" \
    "${REPO_ROOT}/" "${USER}@${FQDN}:/home/${USER}/dmcshop-sql2025/"

echo "==> publish + restart"
ssh "${SSH_OPTS[@]}" "${USER}@${FQDN}" 'bash -se' <<'REMOTE'
set -euo pipefail
cd ~/dmcshop-sql2025/app

dotnet publish src/DMCShop.Web -c Release -o /home/dmcshop/dmcshop-publish --nologo 2>&1 | tail -5

sudo systemctl restart dmcshop-web
sleep 4
sudo systemctl status dmcshop-web --no-pager | head -6
REMOTE

echo "==> tamam → http://${FQDN}"
