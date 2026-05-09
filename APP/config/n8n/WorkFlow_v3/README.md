# WorkFlow_v3

Workflows n8n v3 para reportes SMTP, con configuracion centralizada, ejecucion por manual/cron/webhook y renderizado HTML basado en contratos + parciales.

## Objetivo

Separar configuracion compartida, parametros del flujo, contratos de reporte, parciales HTML y logica de datos para reducir mantenimiento sobre workflows productivos.

## Estructura

- `SYS - Configuracion base reportes correo.json`: subworkflow central para `SetBase`.
- `*- SMTP.json`: workflows de reporte migrados a arquitectura v3.
- Los workflows v3 consumen la version central `SYS` mediante el nodo `SubWorkflow - SetBase reportes correo`.

## Patron v3

1. Trigger manual, webhook o cron.
2. `SetTrigger - Flujo`.
3. `SubWorkflow - SetBase reportes correo`.
4. `Config Reporte` o `SetMixed - Configuracion efectiva`.
5. Consulta de datos.
6. Preparación de datos.
7. `HTML - Renderer parciales`: lee `report_template_key`, carga `reports/*.json` y compone el correo con `partials/*.html`.
8. Envío SMTP.

## Contrato comun

`SetBase` entrega valores comunes:

- `Company` / `company`
- `timezone`
- `email_from`
- `email_to`
- `email_cc`
- `email_bcc`
- `itop_url`
- `itop_organization`
- `itop_limit`
- `template_root`
- `source_label`
- `flags`

Flags comunes:

- `include_attachment`
- `include_summary`
- `include_detail`
- `include_operational_notes`
- `include_itop_button_footer`

`SetTrigger - Flujo` entrega valores específicos del workflow:

- `email_subject`
- `report_mode`
- `csv_basename`
- `report_title`
- `report_description`
- `operational_notes`
- parámetros propios del reporte
- destinatarios por defecto del flujo
- overrides recibidos por webhook

La prioridad de mezcla es:

`SetTrigger - Flujo` > `SetBase`

## Webhook

Todos los workflows de reporte v3 tienen webhook `POST` con `HeaderAuth`.

Header requerido:

```text
X-Webhook-Token: <token configurado en la credencial HeaderAuth>
```

Parámetros funcionales comunes, siempre en body JSON:

```json
{
  "email_to": "usuario1@company.com",
  "email_cc": "",
  "email_bcc": "",
  "include_attachment": true,
  "include_summary": true,
  "include_detail": true,
  "include_operational_notes": true,
  "include_itop_button_footer": true
}
```

Parámetros de ventana soportados por los flujos que usan fechas:

```json
{
  "movement_days": 7,
  "start_date": "2026-05-01 00:00:00",
  "end_date": "2026-05-08 23:59:59",
  "warranty_warning_months": 12,
  "stale_threshold_hours": 24
}
```

`start_date` y `end_date` son los únicos nombres públicos para ventanas de fecha. No se aceptan aliases.

No se usan query params ni headers para parámetros funcionales del reporte.

## Webhooks disponibles

- `POST /webhook/cmdb-activos-garantia-vencida`
- `POST /webhook/cmdb-activos-garantia-vigente`
- `POST /webhook/cmdb-activos-disponibles-bodega`
- `POST /webhook/cmdb-activos-proximos-vencer-garantia`
- `POST /webhook/cmdb-activos-sin-contacto`
- `POST /webhook/cmdb-inventario-activos-contactos`
- `POST /webhook/cmdb-movimientos-recientes-inventario`
- `POST /webhook/cmdb-resumen-clase-estado-bodega`
- `POST /webhook/itsm-tickets-abiertos-agente`
- `POST /webhook/itsm-tickets-abiertos-antiguedad`
- `POST /webhook/itsm-tickets-sin-actualizacion-24h`

## Cron

Todos los workflows de reporte v3 incluyen cron semanal:

- Lunes a las 07:00.

## Templates

Los templates viven en:

`../templates/mail/v1`

Dentro del contenedor n8n se montan en:

`/opt/n8n-config/templates/mail/v1`

Todos los workflows v3 usan `HTML - Renderer parciales`. Cada flujo define `report_template_key` en `SetTrigger - Flujo`; ese valor selecciona el contrato en `reports/*.json`, y el contrato selecciona los parciales en `partials/*.html`.

## Adjuntos SMTP

En v3, el renderer por parciales define `attachment_binary_names`.

- Si `flags.include_attachment` es `true` y existe `binary.csv`, retorna `attachment_binary_names = "csv"`.
- Si `flags.include_attachment` es `false`, retorna `attachment_binary_names = ""` y remueve binarios del item.

Todos los workflows v3 usan el manejo de adjunto centralizado del renderer por parciales.

## Nombres de adjuntos

Los flujos mantienen el nombre de adjunto generado por su nodo de preparaci?n de datos; el renderer solo decide si adjunta o no el binario `csv`.

Formato final:

`<csv_basename>_YYYYMMDD_HHMM.csv`

Ejemplo:

`cmdb_activos_sin_contacto_20260507_2340.csv`

## Nota de alcance

Esta etapa mantiene salida SMTP. No incorpora todavía retorno JSON para reportería externa, aunque el contrato deja campos y flags preparados para esa evolución.
