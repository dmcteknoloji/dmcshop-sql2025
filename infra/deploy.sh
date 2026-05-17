#!/usr/bin/env bash
# ============================================================================
# infra/deploy.sh
# Tek komutla DMCShop demo Azure ortamı:
#   1) ~/.ssh/dmcshop_ed25519 yoksa SSH key üretir
#   2) RG oluşturur, main.bicep deploy eder
#   3) cloud-init bitmesini bekler (/var/lib/dmcshop-ready)
#   4) rsync ile repo'yu VM'ye gönderir
#   5) Remote: docker compose + bootstrap + embed-products + systemd start
#
# Bir defalık kurulum sonrası tekrar çalıştırmak idempotent değildir — repo'yu
# güncellemek için scripts/deploy-sync.sh kullanın.
# ============================================================================

set -euo pipefail

# ---- ayarlar (env ile override edilebilir) --------------------------------
: "${DMCSHOP_RG:=rg-dmcshop-demo}"
: "${DMCSHOP_LOCATION:=germanywestcentral}"
: "${DMCSHOP_NAME_PREFIX:=dmcshop}"
: "${DMCSHOP_VM_SIZE:=Standard_B2ms}"
: "${DMCSHOP_SA_PASSWORD:=dmcShop_2026!Demo}"
: "${DMCSHOP_SSH_KEY:=$HOME/.ssh/dmcshop_ed25519}"
: "${DMCSHOP_ALLOWED_CIDR:=*}"   # production için kendi IP/32

# ---- yol hesaplamaları ----------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> DMCShop Azure deployment"
echo "    RG:       ${DMCSHOP_RG}"
echo "    Location: ${DMCSHOP_LOCATION}"
echo "    VM size:  ${DMCSHOP_VM_SIZE}"
echo "    SSH key:  ${DMCSHOP_SSH_KEY}"

# ---- önkoşullar -----------------------------------------------------------
command -v az    >/dev/null || { echo "az CLI gerekli"; exit 1; }
command -v rsync >/dev/null || { echo "rsync gerekli";  exit 1; }
az account show -o none

# ---- 1) SSH key --------------------------------------------------------
if [[ ! -f "${DMCSHOP_SSH_KEY}" ]]; then
    echo "==> SSH key üretiliyor: ${DMCSHOP_SSH_KEY}"
    ssh-keygen -t ed25519 -N "" -C "dmcshop-demo" -f "${DMCSHOP_SSH_KEY}"
fi
SSH_PUB="$(cat "${DMCSHOP_SSH_KEY}.pub")"

# ---- 2) RG + Bicep deployment ------------------------------------------
echo "==> Resource Group oluşturuluyor"
az group create -n "${DMCSHOP_RG}" -l "${DMCSHOP_LOCATION}" -o table

CLOUD_INIT_B64="$(base64 < "${SCRIPT_DIR}/cloud-init.yaml" | tr -d '\n')"

echo "==> Bicep deployment (3-5 dakika)"
DEPLOYMENT_OUT="$(az deployment group create \
    --resource-group "${DMCSHOP_RG}" \
    --name "dmcshop-$(date +%s)" \
    --template-file "${SCRIPT_DIR}/main.bicep" \
    --parameters \
        namePrefix="${DMCSHOP_NAME_PREFIX}" \
        vmSize="${DMCSHOP_VM_SIZE}" \
        adminSshPublicKey="${SSH_PUB}" \
        cloudInitBase64="${CLOUD_INIT_B64}" \
        allowedClientCidr="${DMCSHOP_ALLOWED_CIDR}" \
    --output json)"

FQDN="$(echo "${DEPLOYMENT_OUT}"      | jq -r '.properties.outputs.fqdn.value')"
PUBLIC_IP="$(echo "${DEPLOYMENT_OUT}" | jq -r '.properties.outputs.publicIp.value')"
USER="$(echo "${DEPLOYMENT_OUT}"      | jq -r '.properties.outputs.adminUsername.value')"

echo ""
echo "==> VM hazır"
echo "    FQDN:      ${FQDN}"
echo "    Public IP: ${PUBLIC_IP}"
echo "    SSH:       ssh -i ${DMCSHOP_SSH_KEY} ${USER}@${FQDN}"

# ---- 3) cloud-init bitmesini bekle -------------------------------------
SSH_OPTS=(-i "${DMCSHOP_SSH_KEY}" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)

echo "==> cloud-init bitmesi bekleniyor (5-8 dakika)"
for attempt in {1..60}; do
    if ssh "${SSH_OPTS[@]}" "${USER}@${FQDN}" "test -f /var/lib/dmcshop-ready" 2>/dev/null; then
        echo "    hazır"
        break
    fi
    sleep 10
    echo -n "."
done

# ---- 4) repo rsync ------------------------------------------------------
echo "==> Repo VM'ye gönderiliyor"
rsync -azh --delete \
    --exclude '.git/' \
    --exclude 'app/**/bin/' \
    --exclude 'app/**/obj/' \
    --exclude '.vs/' \
    --exclude 'appsettings.Local.json' \
    -e "ssh ${SSH_OPTS[*]}" \
    "${REPO_ROOT}/" "${USER}@${FQDN}:/home/${USER}/dmcshop-sql2025/"

# ---- 5) remote bootstrap + embed + service -----------------------------
echo "==> Remote: docker compose + bootstrap + embed-products"
ssh "${SSH_OPTS[@]}" "${USER}@${FQDN}" "DMCSHOP_SA_PASSWORD='${DMCSHOP_SA_PASSWORD}' bash -se" <<'REMOTE'
set -euo pipefail
cd ~/dmcshop-sql2025

echo "  -> docker compose up"
docker compose -f scripts/docker-compose.yml up -d
echo "  -> SQL Server health bekleniyor"
for i in {1..30}; do
    if docker exec dmcshop-mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "${DMCSHOP_SA_PASSWORD}" -Q "SELECT 1" >/dev/null 2>&1; then
        break
    fi
    sleep 5
done

echo "  -> ollama model pull"
docker exec dmcshop-ollama ollama pull nomic-embed-text

echo "  -> bootstrap (schema + seed)"
./scripts/bootstrap.sh

echo "  -> dotnet restore + publish (cold start uzun)"
cd app
dotnet restore
dotnet publish src/DMCShop.Web -c Release -o /home/dmcshop/dmcshop-publish --nologo

echo "  -> embed-products"
dotnet run -c Release --project src/DMCShop.Cli -- embed-products

echo "  -> systemd service"
sudo systemctl daemon-reload
sudo systemctl enable --now dmcshop-web.service
sleep 5
sudo systemctl status dmcshop-web.service --no-pager | head -10
REMOTE

echo ""
echo "==> Deploy tamam"
echo "    Web:  http://${FQDN}"
echo "    SSH:  ssh -i ${DMCSHOP_SSH_KEY} ${USER}@${FQDN}"
echo ""
echo "    Logs: ssh -i ${DMCSHOP_SSH_KEY} ${USER}@${FQDN} 'sudo journalctl -u dmcshop-web -f'"
echo "    Teardown: ./infra/teardown.sh"
