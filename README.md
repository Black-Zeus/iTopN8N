# iTop + n8n Integration Stack

Stack Docker Compose para automatizaciones y reportes operacionales sobre Combodo iTop usando n8n, PostgreSQL, Redis, NocoDB, Mailpit y nginx como punto unico de entrada.

## Estado Actual

- Entrada unica desde el host via nginx: `http://localhost:8083/`
- n8n publicado bajo subpath: `http://localhost:8083/n8n/`
- NocoDB publicado bajo subpath: `http://localhost:8083/nocodb/`
- Mailpit publicado bajo subpath: `http://localhost:8083/mailpit/`
- En `dev` y `qa`, PostgreSQL, n8n, NocoDB y Mailpit tambien pueden publicarse directo mediante `docker-compose.dev.yml` / `docker-compose.qa.yml`.
- En `prd`, esos servicios quedan solo en la red interna Docker.
- Los workflows productivos viven en `APP/config/n8n/WorkFlows`.
- Los workflows v2 viven en `APP/config/n8n/WorkFlow_v2`.
- Los templates HTML desacoplados viven en `APP/config/n8n/templates/mail/v1`.

## Arquitectura

```text
Host
  |
  | http://localhost:8083
  v
nginx
  |-- /n8n/     -> n8n_main:5678
  |-- /nocodb/  -> nocodb:8080
  |-- /mailpit/ -> mailpit:8025

Red Docker interna
  |-- n8n_main
  |-- n8n_worker
  |-- postgres
  |-- redis
  |-- nocodb
  |-- mailpit
```

## Servicios

| Servicio | Rol | Exposicion |
|---|---|---|
| `nginx` | Reverse proxy y portal operacional | Host `8083` |
| `n8n` | UI, webhooks, triggers y coordinacion | Interno `5678` |
| `n8n_worker` | Ejecucion de workflows en modo queue | Interno |
| `postgres` | Persistencia de n8n y NocoDB | Interno `5432` |
| `redis` | Cola Bull para n8n | Interno `6379` |
| `nocodb` | Administracion visual de datos auxiliares | Interno `8080` |
| `mailpit` | SMTP y bandeja de correos de prueba | Interno `1025` / `8025` |

## URLs

```text
Portal:  http://localhost:8083/
n8n:     http://localhost:8083/n8n/
NocoDB:  http://localhost:8083/nocodb/
Mailpit: http://localhost:8083/mailpit/
```

En `prd`, no usar accesos directos como `localhost:5678`, `localhost:8025` o `localhost:8080`; deben quedar detras del proxy.

## Estructura Relevante

```text
.
|-- docker-compose.yml
|-- .env.example
|-- .env                     # no versionar
|-- APP/
|   |-- config/
|   |   |-- nginx/
|   |   |   |-- nginx.conf
|   |   |   `-- html/index.html
|   |   |-- n8n/
|   |   |   |-- WorkFlows/      # workflows actuales / productivos
|   |   |   |-- WorkFlow_v2/    # workflows v2 versionables
|   |   |   `-- templates/
|   |   |       `-- mail/v1/    # parciales HTML y contratos de reporte
|   |   `-- postgres/init.sql
|   `-- volumes/               # datos runtime, excluidos de Git
```

## Workflows

### Version actual

`APP/config/n8n/WorkFlows` contiene los flujos actuales exportados desde n8n.

Documentacion del catalogo:

```text
APP/config/n8n/WorkFlows/README.md
```

### WorkFlow_v2

`APP/config/n8n/WorkFlow_v2` contiene la migracion v2 de los reportes SMTP:

```text
SYS - Configuracion base reportes correo.json
CMDB - Activos sin contacto asignado - SMTP.json
CMDB - ... - SMTP.json
ITSM - ... - SMTP.json
README.md
```

El patron v2 separa:

```text
Trigger
SetTrigger - Flujo
SubWorkflow - SetBase reportes correo
Config Reporte / SetMixed - Configuracion efectiva
Consulta de datos
Preparacion de datos
HTML - Renderer parciales
Envio SMTP
```

### Templates HTML

Los templates de correo estan desacoplados en:

```text
APP/config/n8n/templates/mail/v1
```

Dentro del contenedor se montan como solo lectura en:

```text
/opt/n8n-config/templates/mail/v1
```

El primer renderer migrado a parciales usa:

```text
partials/layout.html
partials/styles.html
partials/header.html
partials/summary.html
partials/stats.html
partials/criteria.html
partials/tables.html
partials/notes.html
partials/cta.html
partials/footer.html
```

Los contratos por reporte viven en:

```text
reports/*.json
```

`cmdb-activos-sin-contacto.json` es específico de ese flujo; no es un contrato genérico.

## Montajes n8n

`docker-compose.yml` monta la configuracion n8n en el contenedor:

```yaml
- ./APP/config/n8n:/opt/n8n-config:ro
```

Tambien habilita lectura de archivos en nodos Code:

```yaml
NODE_FUNCTION_ALLOW_BUILTIN: fs,path
```

Esto permite que el workflow lea templates externos sin mantener HTML embebido en nodos productivos.

## Variables Principales

| Variable | Descripcion |
|---|---|
| `NGINX_HTTP_PORT` | Puerto publicado por nginx al host. Actualmente `8083`. |
| `N8N_EDITOR_BASE_URL` | URL publica del editor n8n. |
| `N8N_WEBHOOK_URL` | URL publica base de webhooks n8n. |
| `N8N_HOST` | Host esperado por n8n. Para local: `localhost`. |
| `N8N_PATH` | Fijado en compose como `/n8n/`. |
| `N8N_PROXY_HOPS` | Fijado en `1` para operar tras nginx. |
| `POSTGRES_*` | Credenciales y base de datos PostgreSQL. |
| `REDIS_PASSWORD` | Password de Redis. |
| `N8N_ENCRYPTION_KEY` | Clave de cifrado de credenciales n8n. No cambiar tras primer arranque. |
| `NOCODB_PUBLIC_URL` | URL publica de NocoDB tras nginx. |
| `MAILPIT_*` | Puertos internos/directos de Mailpit segun override de ambiente. |

## Operacion Basica

Levantar o recrear el stack:

```powershell
docker compose up -d
```

Recrear servicios tras cambios en compose o montajes:

```powershell
docker compose up -d --force-recreate n8n n8n_worker nginx
```

Ver estado:

```powershell
docker compose ps
```

Ver logs:

```powershell
docker compose logs --tail=100 n8n
docker compose logs --tail=100 nginx
docker compose logs --tail=100 mailpit
```

Healthchecks rapidos:

```powershell
curl.exe -s -o NUL -w "n8n=%{http_code}`n" http://localhost:8083/n8n/healthz
curl.exe -s -o NUL -w "mailpit=%{http_code}`n" http://localhost:8083/mailpit/
```

Validar que solo nginx este expuesto al host:

```powershell
docker compose ps
```

En `prd` debe aparecer unicamente nginx con `0.0.0.0:8083->80/tcp`.

## Importar Workflows v2

Los JSON de `APP/config/n8n/WorkFlow_v2` estan preparados para importarse en n8n dentro de la carpeta del cliente.

Para importar:

1. Importar `SYS - Configuracion base reportes correo.json`.
2. Importar los workflows `*- SMTP.json` requeridos desde `WorkFlow_v2`.
3. Moverlos dentro de la carpeta del cliente en n8n.
4. Publicar/activar los workflows necesarios.
5. Revisar credenciales iTop, SMTP y `HeaderAuth`.
6. Ejecutar manualmente o probar webhook.

Los workflows llaman al subworkflow `SYS - Configuracion base reportes correo` desde n8n usando el nodo `Execute Workflow` en modo Database/lista. Si se reimporta el SYS y n8n genera un nuevo ID, actualizar la referencia del nodo:

```text
SubWorkflow - SetBase reportes correo
```

## Versionamiento

Se versiona:

- Compose y configuracion nginx.
- Portal `index.html`.
- Workflows exportados.
- Workflows `WorkFlow_v2`.
- Templates HTML desacoplados.
- Documentacion.

No se versiona:

- `.env`
- datos runtime en `APP/volumes`
- backups locales
- logs y temporales

### Regla operativa Git

Las acciones `git commit`, `git pull` y `git push` solo deben ejecutarse cuando exista una solicitud textual explicita del responsable del proyecto. Los cambios pueden prepararse, revisar diff y validarse localmente, pero no se versionan ni sincronizan sin esa confirmacion.

## Seguridad

- Mantener `.env` fuera de Git.
- No publicar puertos internos de base de datos, n8n, NocoDB o Mailpit.
- Usar Mailpit solo para pruebas SMTP.
- Mantener `N8N_ENCRYPTION_KEY` estable durante todo el ciclo de vida del stack.
- Para uso con dominio real, mover a HTTPS y ajustar `N8N_PROTOCOL`, `N8N_EDITOR_BASE_URL`, `N8N_WEBHOOK_URL` y CORS de Mailpit si aplica.
