#!/usr/bin/env bash
# ============================================================================
# run-dev.sh
# Geliştirme ortamında Blazor Web uygulamasını çalıştırır.
# Önkoşul: bootstrap.sh tamamlandı.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}/app"
exec dotnet run --project src/DMCShop.Web --launch-profile https
