#!/usr/bin/env bash
# ============================================================================
# scripts/sa-password.sh   (source edilir, calistirilmaz)
#
# SA parolasini cozer ve DMCSHOP_SA_PASSWORD olarak disari verir.
# Sira:
#   1) Ortamda DMCSHOP_SA_PASSWORD varsa onu kullanir
#   2) scripts/.env icinde varsa oradan okur
#   3) Yoksa rastgele uretir ve scripts/.env dosyasina (0600) yazar
#
# Neden: onceki varsayilan (`dmcShop_2026!Demo`) bu PUBLIC depoda yaziliydi.
# Herkesin bildigi bir parolayla SQL Server ayaga kalkiyordu ve ayni deger
# appsettings.json icindeki baglanti dizesinde de duruyordu.
#
# scripts/.env, compose'un proje dizini oldugu icin
# `docker compose -f scripts/docker-compose.yml up` tarafindan kendiliginden
# okunur; ayrica export etmek gerekmez.
# ============================================================================

_sa_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_sa_env="${_sa_dir}/.env"

if [[ -z "${DMCSHOP_SA_PASSWORD:-}" && -f "${_sa_env}" ]]; then
    DMCSHOP_SA_PASSWORD="$(sed -n 's/^DMCSHOP_SA_PASSWORD=//p' "${_sa_env}" | head -1)"
fi

if [[ -z "${DMCSHOP_SA_PASSWORD:-}" ]]; then
    # `tr </dev/urandom | head -c N` kalibi kullanilmiyor: head boruyu erken
    # kapatiyor, tr SIGPIPE aliyor ve `set -o pipefail` altinda betik 141 ile
    # dusuyor. Sinirli miktarda okuyup bash ile kesiyoruz.
    _sa_raw="$(LC_ALL=C tr -dc 'A-Za-z0-9' < <(head -c 1024 /dev/urandom))"
    DMCSHOP_SA_PASSWORD="${_sa_raw:0:24}Aa1!"
    umask 077
    if [[ -f "${_sa_env}" ]]; then
        printf 'DMCSHOP_SA_PASSWORD=%s\n' "${DMCSHOP_SA_PASSWORD}" >> "${_sa_env}"
    else
        printf '# scripts/setup.sh tarafindan uretildi. .gitignore kapsaminda.\nDMCSHOP_SA_PASSWORD=%s\n' \
            "${DMCSHOP_SA_PASSWORD}" > "${_sa_env}"
    fi
    chmod 0600 "${_sa_env}"
    echo "==> SA parolasi uretildi ve ${_sa_env} icine yazildi (0600)."
fi

export DMCSHOP_SA_PASSWORD

# Uygulamalar baglanti dizesini ortamdan alir; appsettings.json'da parola yok.
: "${DMCSHOP_HOST:=127.0.0.1,1433}"
_sa_conn="Server=${DMCSHOP_HOST};Database=dmcshop;User Id=sa;Password=${DMCSHOP_SA_PASSWORD};TrustServerCertificate=true;Encrypt=true"
export ConnectionStrings__DMCShop="${_sa_conn}"
export DMCSHOP_ConnectionStrings__DMCShop="${_sa_conn}"

unset _sa_dir _sa_env _sa_conn _sa_raw
