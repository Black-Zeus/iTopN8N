# Importar recursos n8n

Script interactivo para importar credenciales y/o workflows JSON en n8n.

## Uso

Desde Git Bash, en la raiz del proyecto:

```bash
bash scripts/import.sh
```

En CMD puedes invocarlo usando Git Bash:

```cmd
"C:\Program Files\Git\bin\bash.exe" scripts/import.sh
```

## Que pregunta

- Que tipo de importacion ejecutar:
  - Credenciales.
  - Flujos.
  - Credenciales y flujos.
- Proyecto destino de n8n.
- Para credenciales: archivo o carpeta local bajo `APP/config/n8n`.
- Nombre de la carpeta destino en n8n.
- Carpeta local con workflows JSON. Por defecto: `APP/config/n8n/WorkFlow_v3`.
- Que credencial usar para `SMTP`, `Header Auth` e `iTop Token API`.
- Si debe importar `SYS` primero. Recomendado: `s`, porque los reportes llaman al subworkflow base.
- Otros workflows que deban importarse primero. Se puede dejar vacio si el orden restante es indiferente.
- Antes de importar workflows valida que todas las conexiones apunten a nodos existentes.
- Si debe forzar `active=true`.
- Si debe publicar todos los workflows importados, en el mismo orden usado para importar.
- Si debe reiniciar `n8n` y `n8n_worker` al finalizar. Esta es la ultima pregunta del flujo de workflows.

## Notas

- El script usa Bash, `docker compose exec`, el CLI interno `n8n import:workflow` y `psql` dentro del contenedor Postgres.
- La carpeta origen debe estar bajo `APP/config/n8n`, porque esa ruta esta montada en el contenedor como `/opt/n8n-config`.
- En Git Bash se desactiva la conversion automatica de rutas para las llamadas al contenedor, asi `/opt/n8n-config/...` llega como ruta Linux real.
- Antes de importar workflows, el script crea copias temporales y actualiza las referencias de credenciales por tipo: `smtp`, `httpHeaderAuth` e `iTopTokenApi`.
- Al publicar workflows usa `n8n publish:workflow --id <workflow_id>` uno por uno, respetando el orden de importacion, y actualiza `workflow_published_version` para asegurar que n8n cargue la version publicada.
- No se recomienda versionar credenciales reales con tokens o passwords. Para importar credenciales, usa un JSON local bajo `APP/config/n8n` y dejalo fuera de Git si contiene secretos.
- Despues de importar, el script actualiza `workflow_entity.parentFolderId` para mover los workflows a la carpeta elegida.
- Si existen workflows con los mismos IDs, n8n puede actualizarlos en vez de crear copias nuevas. Para ambientes paralelos con IDs nuevos, conviene preparar una variante especifica del export antes de importar.
- El script se ejecuta desde el host. Ejecutarlo dentro del contenedor n8n no es ideal porque ese contenedor no tiene acceso directo a Docker Compose ni necesariamente a `psql`.
