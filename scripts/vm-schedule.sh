#!/usr/bin/env bash
# ============================================================================
# scripts/vm-schedule.sh
# Azure VM start / stop helper. Workshop dışı saatlerde VM'i deallocate
# ederek maliyeti azaltır (~$130/ay → ~$13/ay disk-only).
#
# Komutlar:
#   ./scripts/vm-schedule.sh start     # VM'i ayağa kaldır
#   ./scripts/vm-schedule.sh stop      # deallocate (compute faturalandırması durur)
#   ./scripts/vm-schedule.sh status    # mevcut durum
#
# GitHub Actions ile cron örnek:
#   - cron: '0 6 * * 1-5'    # hafta içi 06:00 UTC başlat
#     run: ./scripts/vm-schedule.sh start
#   - cron: '0 18 * * 1-5'   # hafta içi 18:00 UTC durdur
#     run: ./scripts/vm-schedule.sh stop
# Bunun için bir az service principal + GitHub secrets gerek.
# ============================================================================

set -euo pipefail

: "${DMCSHOP_RG:=rg-dmcshop-demo}"
: "${DMCSHOP_NAME_PREFIX:=dmcshop}"

VM_NAME="${DMCSHOP_NAME_PREFIX}-vm"

cmd="${1:-status}"

case "${cmd}" in
    start)
        echo "==> VM start: ${VM_NAME}"
        az vm start --resource-group "${DMCSHOP_RG}" --name "${VM_NAME}"
        echo "==> Public IP / FQDN:"
        az network public-ip show \
            -g "${DMCSHOP_RG}" -n "${DMCSHOP_NAME_PREFIX}-pip" \
            --query '{ip:ipAddress, fqdn:dnsSettings.fqdn}' -o table
        echo ""
        echo "==> docker compose up — SSH ile:"
        echo "  ssh -i ~/.ssh/dmcshop_ed25519 dmcshop@\$(az network public-ip show -g ${DMCSHOP_RG} -n ${DMCSHOP_NAME_PREFIX}-pip --query dnsSettings.fqdn -o tsv) 'cd ~/dmcshop-sql2025 && docker compose -f scripts/docker-compose.yml up -d'"
        ;;

    stop|deallocate)
        echo "==> VM deallocate: ${VM_NAME}"
        az vm deallocate --resource-group "${DMCSHOP_RG}" --name "${VM_NAME}"
        echo "Compute faturalandırması durdu. Disk + Public IP ücreti devam eder (~\$13/ay)."
        ;;

    status)
        az vm show -d -g "${DMCSHOP_RG}" -n "${VM_NAME}" \
            --query '{Name:name, PowerState:powerState, Size:hardwareProfile.vmSize, IP:publicIps}' -o table
        ;;

    *)
        echo "Kullanım: $0 {start|stop|status}" >&2
        exit 1
        ;;
esac
