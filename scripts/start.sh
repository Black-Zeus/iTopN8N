#!/usr/bin/env bash
# Inicia todos los servicios del stack n8n.
# Uso: ./scripts/start.sh [--build]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

cd "$ROOT"

if [[ ! -f ".env" ]]; then
  echo "[ERROR] Archivo .env no encontrado."
  echo "        Ejecuta primero: ./scripts/init.sh"
  exit 1
fi

# Validar que las claves críticas no sean las de ejemplo
for VAR in N8N_ENCRYPTION_KEY POSTGRES_PASSWORD REDIS_PASSWORD; do
  VALUE=$(grep -E "^${VAR}=" .env | cut -d= -f2- | tr -d '"' || true)
  if [[ "$VALUE" == CHANGEME* ]]; then
    echo "[ERROR] La variable $VAR aún tiene el valor de ejemplo."
    echo "        Edita .env antes de iniciar."
    exit 1
  fi
done

BUILD_FLAG=""
[[ "${1:-}" == "--build" ]] && BUILD_FLAG="--build"

echo "==> Iniciando servicios n8n..."
docker compose up -d $BUILD_FLAG

echo ""
echo "==> Estado del stack:"
docker compose ps

N8N_PORT=$(grep -E '^N8N_EXTERNAL_PORT=' .env | cut -d= -f2 | tr -d '"' || echo "5678")
echo ""
echo "==> n8n disponible en: http://localhost:${N8N_PORT:-5678}"
echo "    Logs: ./scripts/logs.sh"
echo "    Health: ./scripts/health.sh"
