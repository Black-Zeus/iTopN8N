#!/usr/bin/env bash
# Detiene el stack n8n.
# Uso: ./scripts/stop.sh [--volumes]
#   --volumes  También elimina los volúmenes (DESTRUCTIVO — borra todos los datos)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

cd "$ROOT"

if [[ "${1:-}" == "--volumes" ]]; then
  echo "[WARN] La opción --volumes eliminará TODOS los datos persistentes."
  read -rp "¿Confirmar? (escribir 'BORRAR' para continuar): " CONFIRM
  if [[ "$CONFIRM" != "BORRAR" ]]; then
    echo "Cancelado."
    exit 0
  fi
  echo "==> Deteniendo servicios y eliminando volúmenes..."
  docker compose down --volumes
else
  echo "==> Deteniendo servicios n8n..."
  docker compose down
fi

echo "==> Servicios detenidos."
