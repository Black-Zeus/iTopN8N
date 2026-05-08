#!/usr/bin/env bash
# Inicializa el entorno: crea .env desde la plantilla y crea todos los
# directorios persistentes necesarios antes del primer arranque.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

echo "==> Inicializando entorno n8n..."
echo ""

# --- .env ---------------------------------------------------------------------
if [[ ! -f "$ROOT/.env" ]]; then
  cp "$ROOT/.env.example" "$ROOT/.env"
  echo "[OK]   .env creado desde .env.example"
  echo "       ACCION REQUERIDA: edita $ROOT/.env con tus credenciales reales."
else
  echo "[SKIP] .env ya existe — no sobreescrito."
fi

# --- Directorios persistentes -------------------------------------------------
declare -a DIRS=(
  "APP/volumes/n8n/data"
  "APP/volumes/n8n/files"
  "APP/volumes/n8n/backups"
  "APP/volumes/postgres/data"
  "APP/volumes/postgres/backups"
  "APP/volumes/redis/data"
  "APP/volumes/nocodb/data"
)

echo ""
echo "--> Creando directorios de volúmenes..."
for dir in "${DIRS[@]}"; do
  mkdir -p "$ROOT/$dir"
  echo "    $dir"
done

# --- Permisos para n8n (corre como UID 1000 dentro del contenedor) ------------
if chown -R 1000:1000 "$ROOT/APP/volumes/n8n" 2>/dev/null; then
  echo ""
  echo "[OK]   Permisos de APP/volumes/n8n ajustados a UID 1000."
else
  echo ""
  echo "[WARN] No se pudo cambiar el owner de APP/volumes/n8n."
  echo "       Si encuentras errores de permisos, ejecuta:"
  echo "       sudo chown -R 1000:1000 $ROOT/APP/volumes/n8n"
fi

# --- Permisos de scripts ------------------------------------------------------
chmod +x "$SCRIPT_DIR"/*.sh
echo "[OK]   Scripts marcados como ejecutables."

echo ""
echo "==> Inicialización completada."
echo ""
echo "Próximos pasos:"
echo "  1. Edita .env con tus credenciales reales"
echo "  2. Ejecuta: ./scripts/start.sh"
