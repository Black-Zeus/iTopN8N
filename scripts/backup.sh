#!/usr/bin/env bash
# Genera backups de PostgreSQL y los datos de n8n.
# Los archivos se guardan en:
#   APP/volumes/postgres/backups/pg_backup_YYYYMMDD_HHMMSS.sql.gz
#   APP/volumes/n8n/backups/n8n_data_YYYYMMDD_HHMMSS.tar.gz
#
# Uso: ./scripts/backup.sh [--pg-only | --n8n-only]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

cd "$ROOT"

# Cargar variables de entorno
if [[ -f ".env" ]]; then
  set -o allexport
  # shellcheck disable=SC1091
  source .env
  set +o allexport
fi

POSTGRES_DB="${POSTGRES_DB:-n8n_db}"
POSTGRES_USER="${POSTGRES_USER:-n8n_user}"

PG_BACKUP="APP/volumes/postgres/backups/pg_backup_${TIMESTAMP}.sql.gz"
N8N_BACKUP="APP/volumes/n8n/backups/n8n_data_${TIMESTAMP}.tar.gz"

DO_PG=true
DO_N8N=true
case "${1:-}" in
  --pg-only)   DO_N8N=false ;;
  --n8n-only)  DO_PG=false ;;
esac

echo "==> Backup iniciado: $TIMESTAMP"
echo ""

# --- PostgreSQL ---------------------------------------------------------------
if $DO_PG; then
  echo "--> PostgreSQL → $PG_BACKUP"
  mkdir -p "$(dirname "$PG_BACKUP")"
  docker compose exec -T postgres pg_dump \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    --no-password \
    | gzip > "$PG_BACKUP"
  SIZE=$(du -sh "$PG_BACKUP" | cut -f1)
  echo "    [OK] $SIZE"
fi

# --- n8n data (credenciales, workflows exportados, config) --------------------
if $DO_N8N; then
  echo "--> n8n data → $N8N_BACKUP"
  mkdir -p "$(dirname "$N8N_BACKUP")"
  tar -czf "$N8N_BACKUP" \
    --exclude="APP/volumes/n8n/data/crash.journal" \
    -C "APP/volumes/n8n" data
  SIZE=$(du -sh "$N8N_BACKUP" | cut -f1)
  echo "    [OK] $SIZE"
fi

echo ""
echo "==> Backup completado: $TIMESTAMP"
$DO_PG  && echo "    PostgreSQL : $PG_BACKUP"
$DO_N8N && echo "    n8n data   : $N8N_BACKUP"

# Listar últimos 5 backups
echo ""
echo "==> Backups de PostgreSQL disponibles (últimos 5):"
ls -lht "APP/volumes/postgres/backups/" 2>/dev/null | head -6 || true

echo ""
echo "==> Backups de n8n disponibles (últimos 5):"
ls -lht "APP/volumes/n8n/backups/" 2>/dev/null | head -6 || true
