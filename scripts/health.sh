#!/usr/bin/env bash
# Muestra el estado de salud de todos los servicios del stack.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

cd "$ROOT"

# Cargar variables de entorno
if [[ -f ".env" ]]; then
  set -o allexport
  # shellcheck disable=SC1091
  source .env
  set +o allexport
fi

POSTGRES_USER="${POSTGRES_USER:-n8n_user}"
POSTGRES_DB="${POSTGRES_DB:-n8n_db}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
N8N_PORT="${N8N_EXTERNAL_PORT:-5678}"

echo "=== Estado de contenedores ==="
echo ""
docker compose ps
echo ""

echo "=== Health checks ==="
echo ""

# PostgreSQL
if docker compose exec -T postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" -q 2>/dev/null; then
  echo "  [OK]   PostgreSQL: healthy"
else
  echo "  [FAIL] PostgreSQL: no responde"
fi

# Redis
if docker compose exec -T redis redis-cli -a "$REDIS_PASSWORD" ping 2>/dev/null | grep -q PONG; then
  echo "  [OK]   Redis: healthy"
else
  echo "  [FAIL] Redis: no responde"
fi

# n8n HTTP
if curl -sf "http://localhost:${N8N_PORT}/healthz" > /dev/null 2>&1; then
  echo "  [OK]   n8n: healthy → http://localhost:${N8N_PORT}"
else
  echo "  [WARN] n8n: no responde en http://localhost:${N8N_PORT}/healthz"
  echo "         (puede estar iniciando — espera 30s y reintenta)"
fi

echo ""
echo "=== Uso de recursos ==="
echo ""
docker stats --no-stream \
  --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" \
  n8n_main n8n_worker n8n_postgres n8n_redis 2>/dev/null \
  || echo "  (algunos contenedores no están corriendo)"
