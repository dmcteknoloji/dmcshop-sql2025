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
# SA parolasi: env ile verilmezse HER DAGITIMDA rastgele uretilir.
# Onceki varsayilan (`dmcShop_2026!Demo`) bu PUBLIC depoda yaziliydi; yani
# herkesin bildigi bir parolayla SQL Server ayaga kalkiyordu. Uretilen parola
# dagitim sonunda ekrana basilir ve VM'de /opt/dmcshop/.sa-password'a yazilir.
: "${DMCSHOP_SA_PASSWORD:=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)Aa1!}"
: "${DMCSHOP_SSH_KEY:=$HOME/.ssh/dmcshop_ed25519}"
: "${DMCSHOP_ALLOWED_CIDR:=*}"   # production için kendi IP/32
: "${DMCSHOP_DOMAIN:=}"          # verilirse Caddy ile HTTPS (Let's Encrypt)

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
# ⚠️ Heredoc `<<'REMOTE'` TIRNAKLI: icerideki degiskenler YERELDE genislemez,
# uzak kabukta aranir. Bu yuzden gerekli her degisken ssh komut satirinda
# aktarilmali. DMCSHOP_DOMAIN unutulursa Caddy adimi sessizce atlanir.
ssh "${SSH_OPTS[@]}" "${USER}@${FQDN}" \
  "DMCSHOP_SA_PASSWORD='${DMCSHOP_SA_PASSWORD}' DMCSHOP_DOMAIN='${DMCSHOP_DOMAIN:-}' bash -se" <<'REMOTE'
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
# IKI model de sart. Uzun sure yalnizca embedding modeli indiriliyordu:
# arama calisiyor, /asistan sayfasi ise Ollama'dan 404 alip 500 donuyordu.
# scripts/setup.sh ikisini de indiriyordu, Azure yolu ayrisipti.
docker exec dmcshop-ollama ollama pull bge-m3
docker exec dmcshop-ollama ollama pull qwen2.5:3b-instruct-q4_K_M

echo "  -> bootstrap (schema + seed)"
./scripts/bootstrap.sh

echo "  -> dotnet restore + publish (cold start uzun)"
cd app
dotnet restore
dotnet publish src/DMCShop.Web -c Release -o /home/dmcshop/dmcshop-publish --nologo

echo "  -> embed-products"
dotnet run -c Release --project src/DMCShop.Cli -- embed-products

echo "  -> servis ortam dosyasi (baglanti dizesi)"
# appsettings.json PUBLIC depoda ve varsayilan parolayi tasiyor; gercek
# (rastgele uretilen) parola yalnizca burada, 0600 izinli dosyada durur.
# 127.0.0.1: konteyner portu IPv4 loopback'e bagli, `localhost` ::1 olabilir.
sudo install -d -m 0755 /etc/dmcshop
sudo tee /etc/dmcshop/web.env >/dev/null <<ENVEOF
DMCSHOP_ConnectionStrings__DMCShop=Server=127.0.0.1,1433;Database=dmcshop;User Id=sa;Password=${DMCSHOP_SA_PASSWORD};TrustServerCertificate=true;Encrypt=true
ConnectionStrings__DMCShop=Server=127.0.0.1,1433;Database=dmcshop;User Id=sa;Password=${DMCSHOP_SA_PASSWORD};TrustServerCertificate=true;Encrypt=true
ENVEOF
sudo chmod 0600 /etc/dmcshop/web.env

# Uygulama 5000'de dinler; 80/443'u Caddy alir (HTTPS + Let's Encrypt).
# Onceden dogrudan 80'e baglaniyordu ve HTTPS HIC yoktu — kitaptaki basili QR
# bu adrese cikiyor, tarayici "guvenli degil" diyordu (2026-09-03'te olculdu).
sudo sed -i 's|ASPNETCORE_URLS=http://0.0.0.0:80|ASPNETCORE_URLS=http://127.0.0.1:5000|' \
    /etc/systemd/system/dmcshop-web.service 2>/dev/null || true

echo "  -> systemd service"
sudo systemctl daemon-reload
sudo systemctl enable --now dmcshop-web.service
sleep 5
sudo systemctl status dmcshop-web.service --no-pager | head -10

# ── Caddy: HTTPS (Let's Encrypt, TLS-ALPN-01) ──
if [[ -n "${DMCSHOP_DOMAIN:-}" ]]; then
  echo "  -> Caddy (HTTPS: ${DMCSHOP_DOMAIN})"
  printf 'DOMAIN=%s\n' "${DMCSHOP_DOMAIN}" > infra/caddy/.env
  DOMAIN="${DMCSHOP_DOMAIN}" docker compose -f infra/caddy/docker-compose.yml up -d
else
  echo "  -> Caddy atlandi (DMCSHOP_DOMAIN verilmedi; uygulama 5000'de, 80/443 bos)"
fi
REMOTE

echo ""
echo "==> Deploy tamam"
if [[ -n "${DMCSHOP_DOMAIN:-}" ]]; then
  echo "    Web:  https://${DMCSHOP_DOMAIN}   (Let's Encrypt, otomatik yenilenir)"
  echo "          http://${FQDN}  (IP ile; sertifika alan adina bagli)"
else
  echo "    Web:  http://${FQDN}:5000   (HTTPS icin: DMCSHOP_DOMAIN=... ile calistirin)"
fi
echo "    SSH:  ssh -i ${DMCSHOP_SSH_KEY} ${USER}@${FQDN}"
echo ""
echo "    Logs: ssh -i ${DMCSHOP_SSH_KEY} ${USER}@${FQDN} 'sudo journalctl -u dmcshop-web -f'"
echo "    Teardown: ./infra/teardown.sh"
