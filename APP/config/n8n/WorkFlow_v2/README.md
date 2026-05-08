# WorkFlow_v2

PoC de workflows n8n desacoplados para reportes SMTP.

## Objetivo

Separar configuración compartida, parámetros del flujo, templates HTML y lógica de datos para reducir mantenimiento sobre workflows productivos.

## Estructura

- `SYS - Configuracion base reportes correo.json`: subworkflow central para `SetBase`.
- `CMDB - Activos sin contacto asignado - SMTP - v2 POC.json`: flujo piloto.
- El resto de archivos son copia inicial de `../WorkFlows` para migración progresiva.

## Patrón v2

1. `Trigger`
2. `SetTrigger - Flujo`
3. `SubWorkflow - SetBase reportes correo`
4. `SetMixed - Configuracion efectiva`
5. Consulta de datos
6. Preparación de datos
7. `HTML - Renderer parciales`
8. Envío SMTP

## Contrato de configuración

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

`SetTrigger - Flujo` entrega valores específicos:

- `email_subject`
- `report_mode`
- `csv_basename`
- `report_title`
- `report_description`
- `operational_notes`
- `report_template_key`
- flags del flujo, por ejemplo `include_attachment`, `include_detail`, `include_summary`

`SetMixed - Configuracion efectiva` mezcla ambos. La prioridad es:

`SetTrigger - Flujo` > `SetBase`

## Templates

Los templates viven en:

`../templates/mail/v1`

Dentro del contenedor n8n se montan en:

`/opt/n8n-config/templates/mail/v1`

El flujo piloto usa:

`reports/cmdb-activos-sin-contacto.json`

## Nota de alcance

Esta PoC mantiene salida SMTP. No incorpora todavía retorno JSON para reporteria externa, aunque el contrato deja campos y flags preparados para esa evolución.
