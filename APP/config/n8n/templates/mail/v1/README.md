# Mail templates v1

PoC de templates HTML desacoplados para reportes SMTP de n8n.

## Patrón estándar

`layout = header + summary + stats + criteria + tables(1..n) + notes + cta + footer`

Los parciales mantienen estructura con tablas e inline styles para conservar compatibilidad con clientes de correo. Los workflows no deberían contener HTML largo; solo deben entregar datos y seleccionar un contrato de reporte en `reports/*.json`.

## Contrato mínimo del renderer

- `report_template_key`: nombre del contrato en `reports/`.
- `report_title`: título visible y asunto base.
- `report_description`: resumen ejecutivo.
- `generated_at`: fecha renderizada.
- `itop_organization`: organización del cliente.
- `company` / `Company`: marca o razón social.
- `itop_url`: URL usada por CTA.
- `operational_notes`: notas separadas por saltos de línea.
- `detail_blocks`: HTML de tablas ya preparado por el flujo.
- métricas referenciadas desde `stats[].value`.

## Flujo piloto

`cmdb-activos-sin-contacto.json` se usa por `CMDB - Activos sin contacto asignado - SMTP` en `WorkFlow_v2`.
