#!/usr/bin/env bash
# Restaura un backup de PostgreSQL y/o datos de n8n.
# ADVERTENCIA: sobreescribe los datos actuales.
#
# Uso:
#   ./scripts/restore.sh --pg-backup <archivo.sql.gz>
#   ./scripts/restore.sh --pg-backup <archivo.sql.gz> --n8n-backup <archivo.tar.gz>
#   ./scripts/restore.sh --n8n-backup <archivo.tar.gz>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

cd "$ROOT"

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//' | tail -n +2
  exit 1
}

PG_BACKUP=""
N8N_BACKUP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pg-backup)   PG_BACKUP="$2";  shift 2 ;;
    --n8n-backup)  N8N_BACKUP="$2"; shift 2 ;;
    -h|--help)     usage ;;
    *) echo "[ERROR] Argumento desconocido: $1"; usage ;;
  esac
done

if [[ -z "$PG_BACKUP" && -z "$N8N_BACKUP" ]]; then
  usage
fi

# Cargar variables de entorno
if [[ -f ".env" ]]; then
  set -o allexport
  # shellcheck disable=SC1091
  source .env
  set +o allexport
fi

POSTGRES_DB="${POSTGRES_DB:-n8n_db}"
POSTGRES_USER="${POSTGRES_USER:-n8n_user}"

echo "[ADVERTENCIA] Esta operación sobreescribirá los datos actuales."
echo ""
[[ -n "$PG_BACKUP" ]]  && echo "  PostgreSQL : $PG_BACKUP"
[[ -n "$N8N_BACKUP" ]] && echo "  n8n data   : $N8N_BACKUP"
echo ""
read -rp "¿Confirmar restauración? (escribir 'si' para continuar): " CONFIRM
[[ "$CONFIRM" != "si" ]] && echo "Cancelado." && exit 0

# --- PostgreSQL ---------------------------------------------------------------
if [[ -n "$PG_BACKUP" ]]; then
  [[ ! -f "$PG_BACKUP" ]] && echo "[ERROR] Archivo no encontrado: $PG_BACKUP" && exit 1
  echo ""
  echo "--> Restaurando PostgreSQL desde: $PG_BACKUP"
  gunzip -c "$PG_BACKUP" | docker compose exec -T postgres psql \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    --quiet
  echo "    [OK] PostgreSQL restaurado."
fi

# --- n8n data -----------------------------------------------------------------
if [[ -n "$N8N_BACKUP" ]]; then
  [[ ! -f "$N8N_BACKUP" ]] && echo "[ERROR] Archivo no encontrado: $N8N_BACKUP" && exit 1
  echo ""
  echo "--> Deteniendo n8n y worker para restaurar datos..."
  docker compose stop n8n n8n_worker

  echo "--> Restaurando n8n data desde: $N8N_BACKUP"
  rm -rf "APP/volumes/n8n/data"
  mkdir -p "APP/volumes/n8n/data"
  tar -xzf "$N8N_BACKUP" -C "APP/volumes/n8n"

  echo "--> Restableciendo permisos..."
  chown -R 1000:1000 "APP/volumes/n8n/data" 2>/dev/null || \
    echo "    [WARN] No se pudo cambiar owner. Ejecutar: sudo chown -R 1000:1000 APP/volumes/n8n/data"

  echo "--> Reiniciando n8n..."
  docker compose start n8n n8n_worker
  echo "    [OK] n8n data restaurado."
fi

echo ""
echo "==> Restauración completada."
