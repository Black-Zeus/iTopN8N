# Catalogo ejecutivo WorkFlow_v3

Este directorio contiene la tercera version de workflows n8n para reportes operacionales por correo. La version v3 conserva la configuracion comun y parametros por webhook de la version anterior, y migra el renderizado HTML a contratos de reporte mas parciales reutilizables para homologar ajustes visuales.

La columna **Nombre ejecutivo** define una etiqueta corta y estable para referenciar el flujo desde portales, integraciones, menús o reportes externos.

## Convencion v3

- **Nombre del flujo n8n:** nombre visible dentro de n8n.
- **Nombre ejecutivo:** etiqueta funcional para otros sistemas.
- **Webhook path:** ruta relativa bajo `/n8n/webhook/`.
- **Disparadores:** todos los reportes v3 tienen ejecución manual, webhook y cron.
- **Seguridad webhook:** los webhooks usan la credencial `HeaderAuth_GF_QA`.
- **Contrato webhook:** los campos permitidos están documentados en `workflow-webhook-contracts.txt`.
- **Subworkflow base:** `SYS - Configuracion base reportes correo` entrega configuración compartida, flags visuales y valores comunes.

## Flujos de reporte

| Archivo | Nombre del flujo n8n | Nombre ejecutivo | Webhook path | Glosa operacional |
|---|---|---|---|---|
| `CMDB - Activos con garantía vencida - SMTP.json` | CMDB - Activos con garantía vencida - SMTP | Garantías CMDB vencidas | `cmdb-activos-garantia-vencida` | Reporte de activos CMDB no obsoletos cuya garantía ya se encuentra vencida. Permite identificar equipamiento fuera de cobertura, apoyar renovación o reemplazo y priorizar riesgos de continuidad operacional. |
| `CMDB - Activos con garantía vigente - SMTP.json` | CMDB - Activos con garantía vigente - SMTP | Garantías CMDB vigentes | `cmdb-activos-garantia-vigente` | Reporte de activos CMDB no obsoletos con garantía vigente a la fecha de referencia. Entrega una vista de cobertura activa para control de parque, soporte y planificación contractual. |
| `CMDB - Activos disponibles por bodega - SMTP.json` | CMDB - Activos disponibles por bodega - SMTP | Disponibilidad de activos por bodega | `cmdb-activos-disponibles-bodega` | Reporte de activos disponibles en inventario, agrupados por clase y bodega. Facilita revisar stock utilizable para asignaciones, redistribución interna, control físico y planificación de compras. |
| `CMDB - Activos próximos a vencer garantía - SMTP.json` | CMDB - Activos próximos a vencer garantía - SMTP | Próximos vencimientos de garantía | `cmdb-activos-proximos-vencer-garantia` | Reporte de activos CMDB cuya garantía vence dentro de la ventana configurada. Permite anticipar renovaciones, reemplazos o validaciones contractuales antes de quedar fuera de cobertura. |
| `CMDB - Activos sin contacto asignado - SMTP.json` | CMDB - Activos sin contacto asignado - SMTP | Activos sin responsable asignado | `cmdb-activos-sin-contacto` | Reporte de activos físicos en estado productivo sin contacto responsable asociado. Ayuda a detectar brechas de trazabilidad, accountability y control administrativo. |
| `CMDB - Inventario de activos con contactos - SMTP.json` | CMDB - Inventario de activos con contactos - SMTP | Inventario CMDB asignado | `cmdb-inventario-activos-contactos` | Reporte de activos CMDB que poseen contacto asignado. Entrega una vista consolidada del inventario trazable, responsables asociados, estado operacional, ubicación y datos relevantes para seguimiento. |
| `CMDB - Movimientos recientes de inventario - SMTP.json` | CMDB - Movimientos recientes de inventario - SMTP | Movimientos recientes CMDB | `cmdb-movimientos-recientes-inventario` | Reporte de cambios recientes sobre activos CMDB, incluyendo variaciones de estado, ubicación, bodega o asignación. Permite revisar rotación, traslados y modificaciones relevantes del inventario. |
| `CMDB - Resumen por clase, estado y bodega - SMTP.json` | CMDB - Resumen por clase, estado y bodega - SMTP | Resumen ejecutivo CMDB | `cmdb-resumen-clase-estado-bodega` | Reporte consolidado de activos CMDB agrupados por clase, estado y bodega. Entrega una visión transversal del parque, su distribución física y su condición operacional. |
| `ITSM - Tickets abiertos por agente - SMTP.json` | ITSM - Tickets abiertos por agente - SMTP | Backlog ITSM por agente | `itsm-tickets-abiertos-agente` | Reporte de tickets abiertos agrupados por agente asignado. Permite revisar carga operativa, distribución de trabajo, tickets críticos y posibles concentraciones por responsable. |
| `ITSM - Tickets abiertos por antigüedad - SMTP.json` | ITSM - Tickets abiertos por antigüedad - SMTP | Backlog ITSM por antigüedad | `itsm-tickets-abiertos-antiguedad` | Reporte de tickets abiertos organizados por antigüedad. Facilita priorizar casos envejecidos, controlar deuda operativa y revisar la salud general del backlog ITSM. |
| `ITSM - Tickets sin actualización mayor a 24h - SMTP.json` | ITSM - Tickets sin actualización mayor a 24h - SMTP | Tickets ITSM sin actualización | `itsm-tickets-sin-actualizacion-24h` | Reporte de tickets abiertos que no registran actualización dentro del umbral definido. Permite controlar seguimiento, detectar casos sin avance reciente y reforzar disciplina operacional. |

## Flujo de sistema

| Archivo | Nombre del flujo n8n | Nombre ejecutivo | Uso |
|---|---|---|---|
| `SYS - Configuracion base reportes correo.json` | SYS - Configuracion base reportes correo | Configuración base de reportes | Subworkflow centralizado para valores comunes: compañía, zona horaria, remitente, URL iTop, organización, flags visuales y parámetros compartidos. Es invocado por los flujos de reporte y no está pensado como reporte independiente. |

## Parámetros comunes por webhook

Todos los reportes aceptan, como mínimo, estos campos:

```json
{
  "email_to": "usuario@company.com",
  "email_cc": "",
  "email_bcc": "",
  "include_attachment": true,
  "include_summary": true,
  "include_detail": true,
  "include_operational_notes": true,
  "include_itop_button_footer": true
}
```

Reglas generales:

- `email_to` es obligatorio para llamadas por webhook.
- No se aceptan aliases: usar exactamente los nombres del contrato.
- `include_attachment=false` evita adjuntar CSV.
- `include_summary=false` oculta resumen ejecutivo.
- `include_detail=false` oculta tablas y detalle operacional.
- `include_operational_notes=false` oculta observaciones operacionales.
- `include_itop_button_footer=false` oculta el botón de acceso a iTop.
- Si se envía `start_date` o `end_date`, ambos deben venir juntos y ser fechas válidas.

Parámetros específicos relevantes:

| Flujo | Parámetro | Regla |
|---|---|---|
| Próximos vencimientos de garantía | `warranty_warning_months` | Obligatorio por webhook; número mayor a 0. |
| Movimientos recientes CMDB | `movement_days` | Obligatorio si no se envía `start_date` + `end_date`. |
| Garantías CMDB vigentes | `reference_date` | Opcional; fecha usada para calcular vigencia. |
| Tickets ITSM sin actualización | `stale_threshold_hours` | Obligatorio por webhook; número mayor a 0. |
| Reportes ITSM | `include_requirements`, `include_incidents`, `include_changes`, `include_problems` | Flags para incluir o excluir tipos de ticket. |
| Tickets abiertos por agente | `send_only_with_agent_email`, `fallback_agent_email` | Controlan envío a agentes y correo de respaldo. |

## Ejecución y operación

Los flujos v3 están pensados para operar dentro de una carpeta de cliente en n8n, por ejemplo `GF`, manteniendo aislados sus workflows, credenciales y pruebas.

Credenciales usadas por la familia v3:

- `HeaderAuth_GF_QA`: autenticación de webhooks.
- `iTopToken_GF_QA`: acceso a iTop.
- `SMTP_MailPit`: envío SMTP durante pruebas.

Notas operacionales:

- El contrato de integración vive en `workflow-webhook-contracts.txt`.
- Las pruebas manuales por `curl` deben mantenerse por flujo para facilitar validación posterior.
- Los templates parciales de correo viven bajo `APP/config/n8n/templates/mail/v1`.
- No se debe modificar un flujo productivo para cambiar textos o estructura HTML si puede resolverse mediante templates/contratos.
