# Mail templates v1

Templates HTML desacoplados para reportes SMTP de n8n.

## Patrón estándar

`layout = header + summary + stats + criteria + tables(1..n) + notes + cta + footer`

Los parciales mantienen estructura con tablas e inline styles para conservar compatibilidad con clientes de correo. Los workflows deberían entregar datos y seleccionar un contrato de reporte en `reports/*.json`.

## Contrato minimo del renderer

- `report_template_key`: nombre del contrato en `reports/`, sin extension `.json`.
- `report_title`: título visible y asunto base.
- `report_description`: resumen ejecutivo.
- `generated_at`: fecha renderizada.
- `itop_organization`: organización del cliente.
- `company` / `Company`: marca o razón social.
- `itop_url`: URL usada por CTA.
- `operational_notes`: notas separadas por saltos de línea.
- `detail_blocks`: HTML de tablas ya preparado por el flujo.
- metricas referenciadas desde `stats[].value`.

## Contratos

Cada reporte debe tener su propio contrato específico en `reports/`.

El archivo `cmdb-activos-sin-contacto.json` no es genérico: corresponde solo al flujo `CMDB - Activos sin contacto asignado - SMTP`.

Los contratos existentes son:

- `cmdb-activos-disponibles-bodega.json`
- `cmdb-activos-garantia-vencida.json`
- `cmdb-activos-garantia-vigente.json`
- `cmdb-activos-proximos-vencer-garantia.json`
- `cmdb-activos-sin-contacto.json`
- `cmdb-inventario-activos-contactos.json`
- `cmdb-movimientos-recientes-inventario.json`
- `cmdb-resumen-clase-estado-bodega.json`
- `itsm-tickets-abiertos-agente.json`
- `itsm-tickets-abiertos-antiguedad.json`
- `itsm-tickets-sin-actualizacion-24h.json`

## Nota de migración

Por ahora solo `CMDB - Activos sin contacto asignado - SMTP` usa el renderer por parciales. Los demás workflows ya tienen contrato preparado para una migración posterior desde HTML embebido hacia parciales.
