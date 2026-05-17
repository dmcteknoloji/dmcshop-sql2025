#!/usr/bin/env bash
# ============================================================================
# infra/teardown.sh
# Tüm DMCShop Azure kaynaklarını siler. Geri alınamaz — destructive.
# ============================================================================

set -euo pipefail
: "${DMCSHOP_RG:=rg-dmcshop-demo}"

echo "==> ${DMCSHOP_RG} silinecek"
read -r -p "    Devam edilsin mi? (yes/HAYIR): " ANSWER
if [[ "${ANSWER}" != "yes" ]]; then
    echo "iptal"
    exit 0
fi

az group delete --name "${DMCSHOP_RG}" --yes --no-wait
echo "==> Silme arka planda başlatıldı. 'az group show -n ${DMCSHOP_RG}' ile takip edilebilir."
