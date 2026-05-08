# Catálogo ejecutivo de workflows n8n

Este directorio contiene workflows de n8n orientados a reportes operacionales enviados por correo.

La columna **Nombre ejecutivo** define una etiqueta corta, estable y legible para referenciar cada flujo desde otros sistemas, menús, portales o reportes consolidados.

| Archivo | Nombre del flujo n8n | Nombre ejecutivo | Glosa operacional |
|---|---|---|---|
| `CMDB - Activos con garantía vencida - SMTP.json` | CMDB - Activos con garantía vencida - SMTP | Garantías CMDB vencidas | Reporte de activos CMDB cuya garantía se encuentra vencida. Permite identificar equipamiento fuera de cobertura, apoyar decisiones de renovación o reemplazo y priorizar riesgos asociados a continuidad operacional. |
| `CMDB - Activos disponibles por bodega - SMTP.json` | CMDB - Activos disponibles por bodega - SMTP | Disponibilidad de activos por bodega | Reporte de activos disponibles en inventario, organizados por bodega o localidad. Facilita la revisión de stock utilizable para asignaciones, redistribución interna, control de inventario y planificación de compras. |
| `CMDB - Activos próximos a vencer garantía - SMTP.json` | CMDB - Activos próximos a vencer garantía - SMTP | Próximos vencimientos de garantía | Reporte de activos CMDB con garantía próxima a vencer dentro de la ventana configurada. Permite anticipar renovaciones, reemplazos o validaciones contractuales antes de que el activo quede fuera de cobertura. |
| `CMDB - Activos sin contacto asignado - SMTP.json` | CMDB - Activos sin contacto asignado - SMTP | Activos sin responsable asignado | Reporte de activos CMDB en producción que no tienen contacto o responsable asociado. Ayuda a detectar brechas de trazabilidad, mejorar el control administrativo y reducir activos sin accountability operacional. |
| `CMDB - Inventario de activos con contactos - SMTP.json` | CMDB - Inventario de activos con contactos - SMTP | Inventario CMDB asignado | Reporte de activos CMDB con contacto asignado. Entrega una vista consolidada del inventario trazable, sus responsables asociados, estado operacional, ubicación y datos relevantes para control y seguimiento. |
| `CMDB - Movimientos recientes de inventario - SMTP.json` | CMDB - Movimientos recientes de inventario - SMTP | Movimientos recientes CMDB | Reporte de cambios recientes registrados sobre activos CMDB, incluyendo variaciones de estado, ubicación, bodega o asignación. Permite revisar rotación, traslados y modificaciones relevantes del inventario. |
| `CMDB - Resumen por clase, estado y bodega - SMTP.json` | CMDB - Resumen por clase, estado y bodega - SMTP | Resumen ejecutivo CMDB | Reporte consolidado de activos CMDB agrupados por clase, estado y bodega. Entrega una visión transversal de la composición del parque, su distribución física y su condición operacional. |
| `ITSM - Tickets abiertos por agente - SMTP.json` | ITSM - Tickets abiertos por agente - SMTP | Backlog ITSM por agente | Reporte de tickets abiertos agrupados por agente asignado. Permite revisar carga operativa, distribución del trabajo, tickets críticos y posibles concentraciones o cuellos de botella por responsable. |
| `ITSM - Tickets abiertos por antigüedad - SMTP.json` | ITSM - Tickets abiertos por antigüedad - SMTP | Backlog ITSM por antigüedad | Reporte de tickets abiertos organizados según su antigüedad. Facilita la priorización de casos envejecidos, el control de deuda operativa y la revisión de la salud general del backlog ITSM. |
| `ITSM - Tickets sin actualización mayor a 24h - SMTP.json` | ITSM - Tickets sin actualización mayor a 24h - SMTP | Tickets ITSM sin actualización | Reporte de tickets abiertos que no registran actualización dentro del umbral definido. Permite controlar seguimiento, detectar casos sin avance reciente y reforzar la disciplina operacional frente a usuarios o áreas solicitantes. |
| `ITSM - Tickets abiertos por tipo - SMTP.json` | ITSM - Tickets abiertos por tipo - SMTP | Backlog ITSM por tipo de ticket | Reporte de tickets abiertos filtrados o agrupados por tipo de ticket. Permite revisar la composición del backlog, distinguir demandas operativas por categoría y priorizar atención según naturaleza del caso. |

## Convención sugerida

- **Nombre del flujo n8n:** nombre técnico visible dentro de n8n.
- **Nombre ejecutivo:** etiqueta corta, estable y legible para uso en menús, integraciones, reportes externos o catálogos.
- **Glosa operacional:** descripción breve del reporte, indicando qué información entrega y para qué decisión o control operativo sirve.