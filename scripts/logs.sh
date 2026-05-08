#!/usr/bin/env bash
# Muestra los logs del stack (en vivo con -f).
#
# Uso:
#   ./scripts/logs.sh                  → todos los servicios
#   ./scripts/logs.sh n8n              → solo n8n principal
#   ./scripts/logs.sh n8n_worker       → solo el worker
#   ./scripts/logs.sh postgres         → solo PostgreSQL
#   ./scripts/logs.sh redis            → solo Redis
#   ./scripts/logs.sh n8n 200          → n8n, últimas 200 líneas
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

cd "$ROOT"

SERVICE="${1:-}"
LINES="${2:-100}"

if [[ -z "$SERVICE" ]]; then
  docker compose logs --tail="$LINES" -f
else
  docker compose logs --tail="$LINES" -f "$SERVICE"
fi
