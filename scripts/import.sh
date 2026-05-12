#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
N8N_CONFIG_DIR="$ROOT_DIR/APP/config/n8n"
DEFAULT_SOURCE_DIR="$N8N_CONFIG_DIR/WorkFlow_v3"
TMP_IMPORT_DIR=""

cd "$ROOT_DIR"

cleanup() {
  if [[ -n "$TMP_IMPORT_DIR" && -d "$TMP_IMPORT_DIR" ]]; then
    rm -rf "$TMP_IMPORT_DIR"
  fi
}
trap cleanup EXIT

ask() {
  local prompt="$1"
  local default_value="${2:-}"
  local answer

  if [[ -n "$default_value" ]]; then
    read -r -p "$prompt [$default_value]: " answer
    printf '%s' "${answer:-$default_value}"
  else
    read -r -p "$prompt: " answer
    printf '%s' "$answer"
  fi
}

is_yes() {
  local value
  value="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  [[ -z "$value" || "$value" == "s" || "$value" == "si" || "$value" == "y" || "$value" == "yes" || "$value" == "true" || "$value" == "1" ]]
}

sql_quote() {
  local value="${1//\'/\'\'}"
  printf "'%s'" "$value"
}

psql_exec() {
  docker compose exec -T postgres psql -U n8n_user -d n8n_db "$@"
}

docker_exec() {
  # Git Bash/MSYS convierte argumentos tipo /opt/... a C:/Program Files/Git/opt/...
  # Estas variables conservan rutas Linux cuando el comando corre dentro del contenedor.
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' docker compose exec -T "$@"
}

psql_sql() {
  local sql="$1"
  printf '%s\n' "$sql" | psql_exec
}

psql_at() {
  local sql="$1"
  printf '%s\n' "$sql" | psql_exec -At
}

make_id() {
  # n8n usa IDs alfanumericos cortos. Esta variante evita depender de uuidgen.
  od -An -N16 -tx1 /dev/urandom | tr -d ' \n' | cut -c 1-16
}

to_container_path() {
  local source_path="$1"
  local abs_source
  abs_source="$(cd "$(dirname "$source_path")" && pwd)/$(basename "$source_path")"

  case "$abs_source" in
    "$N8N_CONFIG_DIR"/*)
      local rel="${abs_source#"$N8N_CONFIG_DIR"/}"
      printf '/opt/n8n-config/%s' "$rel"
      ;;
    *)
      echo "ERROR: La carpeta origen debe estar dentro de APP/config/n8n porque esa ruta esta montada en /opt/n8n-config." >&2
      exit 1
      ;;
  esac
}

json_field() {
  local field="$1"
  local file="$2"
  if [[ "$field" == "id" ]]; then
    # En exports de n8n hay IDs de nodos dentro de nodes[].
    # El ID del workflow queda al final del JSON, por eso se toma el ultimo.
    grep -E "\"id\"[[:space:]]*:" "$file" \
      | tail -n 1 \
      | sed -E "s/.*\"id\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/"
  else
    grep -m 1 -E "\"$field\"[[:space:]]*:" "$file" \
      | sed -E "s/.*\"$field\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/"
  fi
}

list_projects() {
  psql_at 'select id || '"'"'|'"'"' || name || '"'"'|'"'"' || type from project order by type desc, name;'
}

list_credentials_by_type() {
  local credential_type="$1"
  psql_at "
select id || '|' || name
from credentials_entity
where type = $(sql_quote "$credential_type")
order by name;
"
}

import_credentials_file() {
  local local_path="$1"
  local container_path
  container_path="$(to_container_path "$local_path")"

  echo
  echo "Importando credenciales: $local_path"
  if [[ -d "$local_path" ]]; then
    docker_exec n8n n8n import:credentials --separate --input "$container_path" --projectId "$PROJECT_ID" --include=id,name,type,data
  else
    docker_exec n8n n8n import:credentials --input "$container_path" --projectId "$PROJECT_ID" --include=id,name,type,data
  fi
}

choose_credential() {
  local credential_type="$1"
  local label="$2"
  local preferred_names="$3"
  local required="${4:-s}"

  mapfile -t CREDENTIAL_ROWS < <(list_credentials_by_type "$credential_type")
  if [[ "${#CREDENTIAL_ROWS[@]}" -eq 0 ]]; then
    if is_yes "$required"; then
      echo "ERROR: No hay credenciales tipo $credential_type para $label." >&2
      exit 1
    fi
    CHOSEN_CREDENTIAL_ID=""
    CHOSEN_CREDENTIAL_NAME=""
    return 0
  fi

  local default_number=1
  local preferred
  IFS='|' read -r -a PREFERRED_ARRAY <<< "$preferred_names"
  for i in "${!CREDENTIAL_ROWS[@]}"; do
    IFS='|' read -r cid cname <<< "${CREDENTIAL_ROWS[$i]}"
    for preferred in "${PREFERRED_ARRAY[@]}"; do
      if [[ "$cname" == "$preferred" ]]; then
        default_number="$((i + 1))"
        break 2
      fi
    done
  done

  echo
  echo "Credenciales disponibles para $label ($credential_type):"
  for i in "${!CREDENTIAL_ROWS[@]}"; do
    IFS='|' read -r cid cname <<< "${CREDENTIAL_ROWS[$i]}"
    printf '  %s. %s id=%s\n' "$((i + 1))" "$cname" "$cid"
  done

  local selected_number selected_row
  selected_number="$(ask "Credencial para $label (numero)" "$default_number")"
  selected_row="${CREDENTIAL_ROWS[$((selected_number - 1))]:-}"
  if [[ -z "$selected_row" ]]; then
    echo "ERROR: Credencial invalida para $label." >&2
    exit 1
  fi

  IFS='|' read -r CHOSEN_CREDENTIAL_ID CHOSEN_CREDENTIAL_NAME <<< "$selected_row"
}

find_folder() {
  local project_id="$1"
  local folder_name="$2"
  psql_at "
select id
from folder
where \"projectId\" = $(sql_quote "$project_id")
  and name = $(sql_quote "$folder_name")
  and \"parentFolderId\" is null
order by \"createdAt\" desc
limit 1;
" | tr -d '\r\n'
}

create_folder() {
  local project_id="$1"
  local folder_name="$2"
  local folder_id
  folder_id="$(make_id)"

  psql_sql "
insert into folder (id, name, \"projectId\", \"parentFolderId\", \"createdAt\", \"updatedAt\")
values ($(sql_quote "$folder_id"), $(sql_quote "$folder_name"), $(sql_quote "$project_id"), null, now(), now());
" >/dev/null
  printf '%s' "$folder_id"
}

import_workflow_file() {
  local local_file="$1"
  local container_file
  container_file="$(to_container_path "$local_file")"

  echo
  echo "Importando: $(basename "$local_file")"
  docker_exec n8n n8n import:workflow --input "$container_file" --projectId "$PROJECT_ID"
}

validate_workflow_files() {
  local -a node_args=("$@")
  local node_runner=(node)

  if ! command -v node >/dev/null 2>&1; then
    node_runner=(docker_exec n8n node)
    node_args=()
    local file
    for file in "$@"; do
      node_args+=("$(to_container_path "$file")")
    done
  fi

  "${node_runner[@]}" - "${node_args[@]}" <<'NODE'
const fs = require('fs');
let bad = [];

for (const file of process.argv.slice(2)) {
  const wf = JSON.parse(fs.readFileSync(file, 'utf8'));
  const nodeNames = new Set((wf.nodes || []).map((node) => node.name));
  const connections = wf.connections || {};

  for (const [source, outputs] of Object.entries(connections)) {
    if (!nodeNames.has(source)) {
      bad.push(`${file}: conexion desde nodo inexistente "${source}"`);
    }

    for (const groups of Object.values(outputs || {})) {
      for (const group of groups || []) {
        for (const edge of group || []) {
          if (!nodeNames.has(edge.node)) {
            bad.push(`${file}: conexion hacia nodo inexistente "${edge.node}"`);
          }
        }
      }
    }
  }
}

if (bad.length) {
  console.error('ERROR: Se detectaron conexiones invalidas en workflows:');
  for (const line of bad) console.error(`- ${line}`);
  process.exit(1);
}
NODE
}

patch_credential_reference() {
  local file="$1"
  local credential_key="$2"
  local credential_id="$3"
  local credential_name="$4"

  if [[ -z "$credential_id" || -z "$credential_name" ]]; then return 0; fi

  CRED_KEY="$credential_key" CRED_ID="$credential_id" CRED_NAME="$credential_name" \
    perl -0pi -e '
      my $key = quotemeta($ENV{CRED_KEY});
      my $id = $ENV{CRED_ID};
      my $name = $ENV{CRED_NAME};
      s/("$key"\s*:\s*\{\s*"id"\s*:\s*")[^"]*(",\s*"name"\s*:\s*")[^"]*(")/$1$id$2$name$3/g;
    ' "$file"
}

prepare_workflow_import_files() {
  TMP_IMPORT_DIR="$N8N_CONFIG_DIR/.tmp-workflow-import-$$"
  mkdir -p "$TMP_IMPORT_DIR"

  PATCHED_FILES=()
  local file target
  for file in "$@"; do
    target="$TMP_IMPORT_DIR/$(basename "$file")"
    cp "$file" "$target"
    patch_credential_reference "$target" "smtp" "$SMTP_CREDENTIAL_ID" "$SMTP_CREDENTIAL_NAME"
    patch_credential_reference "$target" "httpHeaderAuth" "$HEADER_CREDENTIAL_ID" "$HEADER_CREDENTIAL_NAME"
    patch_credential_reference "$target" "iTopTokenApi" "$ITOP_CREDENTIAL_ID" "$ITOP_CREDENTIAL_NAME"
    PATCHED_FILES+=("$target")
  done
}

move_to_folder() {
  local folder_id="$1"
  shift

  local ids=()
  local file id
  for file in "$@"; do
    id="$(json_field id "$file")"
    if [[ -n "$id" ]]; then ids+=("$(sql_quote "$id")"); fi
  done

  if [[ "${#ids[@]}" -eq 0 ]]; then
    echo "ERROR: No se encontraron IDs de workflow en los JSON." >&2
    exit 1
  fi

  local joined
  joined="$(IFS=, ; echo "${ids[*]}")"
  psql_sql "
update workflow_entity
set \"parentFolderId\" = $(sql_quote "$folder_id"),
    \"updatedAt\" = now()
where id in ($joined);
"
}

set_active_state() {
  local active="$1"
  shift

  local ids=()
  local file id
  for file in "$@"; do
    id="$(json_field id "$file")"
    if [[ -n "$id" ]]; then ids+=("$(sql_quote "$id")"); fi
  done

  local joined
  joined="$(IFS=, ; echo "${ids[*]}")"
  [[ -z "$joined" ]] && return 0

  psql_sql "
update workflow_entity
set active = $active,
    \"updatedAt\" = now()
where id in ($joined);
"
}

publish_workflow_files() {
  local file id name
  for file in "$@"; do
    id="$(json_field id "$file")"
    name="$(json_field name "$file")"
    if [[ -z "$id" ]]; then
      echo "ERROR: No se encontro ID de workflow en $(basename "$file")." >&2
      exit 1
    fi

    echo
    echo "Publicando: ${name:-$(basename "$file")} ($id)"
    docker_exec n8n n8n publish:workflow --id "$id"
    psql_sql "
insert into workflow_published_version (\"workflowId\", \"publishedVersionId\", \"createdAt\", \"updatedAt\")
select id, \"activeVersionId\", now(), now()
from workflow_entity
where id = $(sql_quote "$id")
  and \"activeVersionId\" is not null
on conflict (\"workflowId\") do update
set \"publishedVersionId\" = excluded.\"publishedVersionId\",
    \"updatedAt\" = now();
"
  done
}

select_project() {
  mapfile -t PROJECT_ROWS < <(list_projects)
  if [[ "${#PROJECT_ROWS[@]}" -eq 0 ]]; then
    echo "ERROR: No hay proyectos en n8n." >&2
    exit 1
  fi

  echo
  echo "Proyectos disponibles:"
  for i in "${!PROJECT_ROWS[@]}"; do
    IFS='|' read -r pid pname ptype <<< "${PROJECT_ROWS[$i]}"
    printf '  %s. %s (%s) id=%s\n' "$((i + 1))" "$pname" "$ptype" "$pid"
  done

  PROJECT_NUMBER="$(ask "Proyecto destino (numero)" "1")"
  PROJECT_ROW="${PROJECT_ROWS[$((PROJECT_NUMBER - 1))]:-}"
  if [[ -z "$PROJECT_ROW" ]]; then
    echo "ERROR: Proyecto invalido." >&2
    exit 1
  fi
  IFS='|' read -r PROJECT_ID PROJECT_NAME PROJECT_TYPE <<< "$PROJECT_ROW"
}

run_credentials_import() {
  CREDENTIALS_INPUT="$(ask "Archivo/carpeta de credenciales bajo APP/config/n8n" "APP/config/n8n/credentials-local")"
  CREDENTIALS_PATH="$ROOT_DIR/$CREDENTIALS_INPUT"
  if [[ "$CREDENTIALS_INPUT" = /* ]]; then CREDENTIALS_PATH="$CREDENTIALS_INPUT"; fi
  if [[ ! -e "$CREDENTIALS_PATH" ]]; then
    echo "ERROR: No existe el archivo/carpeta de credenciales: $CREDENTIALS_PATH" >&2
    exit 1
  fi
  import_credentials_file "$CREDENTIALS_PATH"
}

select_workflow_credentials() {
  choose_credential "smtp" "SMTP/MailPit" "SMTPMailPit|SMTP_MailPit"
  SMTP_CREDENTIAL_ID="$CHOSEN_CREDENTIAL_ID"
  SMTP_CREDENTIAL_NAME="$CHOSEN_CREDENTIAL_NAME"

  choose_credential "httpHeaderAuth" "Header Auth webhook" "Header Auth account|HeaderAuth_GF_QA"
  HEADER_CREDENTIAL_ID="$CHOSEN_CREDENTIAL_ID"
  HEADER_CREDENTIAL_NAME="$CHOSEN_CREDENTIAL_NAME"

  choose_credential "iTopTokenApi" "iTop Token API" "iTop Token account|iTopToken_GF_QA"
  ITOP_CREDENTIAL_ID="$CHOSEN_CREDENTIAL_ID"
  ITOP_CREDENTIAL_NAME="$CHOSEN_CREDENTIAL_NAME"
}

run_workflows_import() {
  FOLDER_NAME="$(ask "Nombre de la carpeta destino en n8n")"
  if [[ -z "$FOLDER_NAME" ]]; then
    echo "ERROR: El nombre de carpeta es obligatorio." >&2
    exit 1
  fi

  SOURCE_INPUT="$(ask "Carpeta local con workflows JSON" "APP/config/n8n/WorkFlow_v3")"
  SOURCE_DIR="$ROOT_DIR/$SOURCE_INPUT"
  if [[ "$SOURCE_INPUT" = /* ]]; then SOURCE_DIR="$SOURCE_INPUT"; fi

  if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "ERROR: No existe la carpeta origen: $SOURCE_DIR" >&2
    exit 1
  fi

  select_workflow_credentials

  mapfile -t ALL_FILES < <(find "$SOURCE_DIR" -maxdepth 1 -type f -name '*.json' | sort)
  if [[ "${#ALL_FILES[@]}" -eq 0 ]]; then
    echo "ERROR: No hay JSON de workflow en $SOURCE_DIR" >&2
    exit 1
  fi

  SYS_FIRST="$(ask "Importar SYS primero? recomendado si hay subworkflows (s/n)" "s")"
  FIRST_EXTRA="$(ask "Otros flujos que deban importarse primero? separar por coma, Enter si orden indiferente" "")"

  ORDERED_FILES=()
  USED_FILES="|"

  add_file_once() {
    local file="$1"
    case "$USED_FILES" in
      *"|$file|"*) return 0 ;;
    esac
    ORDERED_FILES+=("$file")
    USED_FILES="${USED_FILES}${file}|"
  }

  if is_yes "$SYS_FIRST"; then
    for file in "${ALL_FILES[@]}"; do
      base="$(basename "$file")"
      name="$(json_field name "$file")"
      if [[ "$base" =~ ^SYS[[:space:]-] || "$name" =~ ^SYS[[:space:]-] ]]; then
        add_file_once "$file"
      fi
    done
  fi

  if [[ -n "$FIRST_EXTRA" ]]; then
    IFS=',' read -r -a EXTRA_PATTERNS <<< "$FIRST_EXTRA"
    for pattern in "${EXTRA_PATTERNS[@]}"; do
      pattern="$(printf '%s' "$pattern" | sed -E 's/^ +| +$//g' | tr '[:upper:]' '[:lower:]')"
      [[ -z "$pattern" ]] && continue
      for file in "${ALL_FILES[@]}"; do
        base="$(basename "$file" | tr '[:upper:]' '[:lower:]')"
        name="$(json_field name "$file" | tr '[:upper:]' '[:lower:]')"
        id="$(json_field id "$file" | tr '[:upper:]' '[:lower:]')"
        if [[ "$base" == *"$pattern"* || "$name" == *"$pattern"* || "$id" == "$pattern" ]]; then
          add_file_once "$file"
        fi
      done
    done
  fi

  for file in "${ALL_FILES[@]}"; do add_file_once "$file"; done

  echo
  echo "Orden de importacion:"
  for i in "${!ORDERED_FILES[@]}"; do
    printf '  %s. %s\n' "$((i + 1))" "$(basename "${ORDERED_FILES[$i]}")"
  done

  validate_workflow_files "${ORDERED_FILES[@]}"

  CONFIRM="$(ask "Continuar con la importacion de workflows? (s/n)" "s")"
  if ! is_yes "$CONFIRM"; then
    echo "Importacion de workflows cancelada."
    return 0
  fi

  FOLDER_ID="$(find_folder "$PROJECT_ID" "$FOLDER_NAME")"
  if [[ -n "$FOLDER_ID" ]]; then
    REUSE="$(ask "La carpeta ya existe id=$FOLDER_ID. Reutilizarla? (s/n)" "s")"
    if ! is_yes "$REUSE"; then
      FOLDER_ID="$(create_folder "$PROJECT_ID" "$FOLDER_NAME")"
    fi
  else
    FOLDER_ID="$(create_folder "$PROJECT_ID" "$FOLDER_NAME")"
  fi

  echo
  echo "Carpeta destino: $FOLDER_NAME ($FOLDER_ID)"
  echo "Proyecto destino: $PROJECT_NAME ($PROJECT_ID)"
  echo "Credencial SMTP: $SMTP_CREDENTIAL_NAME ($SMTP_CREDENTIAL_ID)"
  echo "Credencial Header Auth: $HEADER_CREDENTIAL_NAME ($HEADER_CREDENTIAL_ID)"
  echo "Credencial iTop: $ITOP_CREDENTIAL_NAME ($ITOP_CREDENTIAL_ID)"

  prepare_workflow_import_files "${ORDERED_FILES[@]}"

  for file in "${PATCHED_FILES[@]}"; do
    import_workflow_file "$file"
  done

  move_to_folder "$FOLDER_ID" "${PATCHED_FILES[@]}"

  ACTIVE_ANSWER="$(ask "Forzar active=true en los workflows importados? (s/n)" "s")"
  if is_yes "$ACTIVE_ANSWER"; then
    set_active_state true "${PATCHED_FILES[@]}"
  fi

  PUBLISH_ANSWER="$(ask "Publicar todos los workflows importados en el mismo orden? (s/n)" "s")"
  if is_yes "$PUBLISH_ANSWER"; then
    publish_workflow_files "${PATCHED_FILES[@]}"
  fi

  RESTART_ANSWER="$(ask "Reiniciar n8n y worker al finalizar? (s/n)" "s")"
  if is_yes "$RESTART_ANSWER"; then
    docker compose restart n8n n8n_worker
  fi

  echo
  echo "Workflows procesados: ${#ORDERED_FILES[@]}"
  echo "Folder: $FOLDER_NAME ($FOLDER_ID)"
}

choose_import_mode() {
  echo
  echo "Que deseas importar?"
  echo "  1. Credenciales"
  echo "  2. Flujos"
  echo "  3. Credenciales y flujos"

  IMPORT_MODE="$(ask "Seleccion" "2")"
  case "$IMPORT_MODE" in
    1) IMPORT_CREDENTIALS=true; IMPORT_WORKFLOWS=false ;;
    2) IMPORT_CREDENTIALS=false; IMPORT_WORKFLOWS=true ;;
    3) IMPORT_CREDENTIALS=true; IMPORT_WORKFLOWS=true ;;
    *)
      echo "ERROR: Seleccion invalida." >&2
      exit 1
      ;;
  esac
}

echo
echo "Importador n8n"
echo "-------------"

choose_import_mode
select_project

if [[ "$IMPORT_CREDENTIALS" == true ]]; then
  run_credentials_import
fi

if [[ "$IMPORT_WORKFLOWS" == true ]]; then
  run_workflows_import
fi

if [[ "$IMPORT_WORKFLOWS" != true ]]; then
  RESTART_ANSWER="$(ask "Reiniciar n8n y worker al finalizar? (s/n)" "s")"
  if is_yes "$RESTART_ANSWER"; then
    docker compose restart n8n n8n_worker
  fi
fi

echo
echo "Importacion terminada."
