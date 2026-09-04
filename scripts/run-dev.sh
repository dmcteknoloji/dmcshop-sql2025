#!/usr/bin/env bash
# ============================================================================
# run-dev.sh
# Geliştirme ortamında Blazor Web uygulamasını çalıştırır.
# Önkoşul: bootstrap.sh tamamlandı.
# ============================================================================

set -euo pipefail

# SA parolasi: ortam -> scripts/.env -> rastgele uret (varsayilan parola YOK).
# ConnectionStrings__DMCShop da burada export edilir.
# shellcheck source=scripts/sa-password.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sa-password.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}/app"
exec dotnet run --project src/DMCShop.Web --launch-profile https
