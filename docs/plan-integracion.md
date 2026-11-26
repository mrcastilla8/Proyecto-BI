# Plan de integración y recuperación

Orden: (1) verificar versiones y contrato/ADR; (2) Castilla crea DDL audit/stg/dw y SQL de control; (3) Poma implementa ingesta en proyecto VS propio y valida fixtures/CSV; (4) Cueva carga dimensiones/hechos con pagos y reviews agregados, prueba idempotencia; (5) reconstruir SQL limpio, ejecutar ETL y conciliar; (6) Basualdo crea/procesa Tabular y coteja DAX con SQL; (7) Ángel conecta Live y verifica páginas; (8) Castilla integra evidencias e informe. Los scripts DDL son reejecutables; las cargas de staging/DW e idempotencia siguen a cargo de los paquetes SSIS.

| Pregunta | Fuente | Transformación | Modelo | Métrica | Visual previsto |
|---|---|---|---|---|---|
| Precio entregado por tiempo | order_items + orders | filtrar delivered, excluir flete | FactDetallePedido, DimFecha | ventas productos entregados | resumen por fecha |
| Pedidos entregados con líneas | orders + order_items | estado/existencia línea | FactDetallePedido | pedidos entregados con ítems | tarjeta/tendencia |
| Cumplimiento promesa | orders | validar fechas | FactPedidos, fecha/geografía | % a tiempo | logística/estado |
| Producto/vendedor | order_items + orders | estado en grano línea | detalle, producto/vendedor | precio, flete, pedidos distintos | ranking/tabla |
| Satisfacción/geografía | reviews + orders + customer | media válida por pedido | FactPedidos, geografía | calificación media | tabla/mapa |

Disponibilidad de campos se confirma en fuentes reales. En fallo, guardar log/rechazo, mantener origen, limpiar solo mediante scripts aprobados y repetir; comprobar no duplicación. Cambio de estrategia/grano exige ADR. Sin resultados o capturas reales por ahora.

## Nivel 2 — Integración Power BI y SSRS (pendiente de aprobación)
El plan de integración y control de cambios del Nivel 2 se especifica en [07_INTEGRACION_POWERBI_SSRS.md](nivel-2/07_INTEGRACION_POWERBI_SSRS.md) y [09_PLAN_INTEGRACION_GIT.md](nivel-2/09_PLAN_INTEGRACION_GIT.md):
- **Puertas de integración (`G0`–`G4`):** preflight de entorno y SSRS (`G0`), aprobación de tema/plantillas/parámetros (`G1`), entregas individuales de 39 tareas (`G2`), integración del PBIX maestro y despliegue de 10 RDL (`G3`), y certificación con evidencia real (`G4`).
- **Custodia única del PBIX maestro:** **Ángel** es el único escritor de `powerbi/BI_OLIST.pbix` durante la integración; los demás integrantes entregan avances individuales sin merge binario.
- **Publicación y enlaces:** **Poma** administra el servidor y publica los 10 RDL en `/OLIST360`. Los botones de Power BI abren URLs fijas de SSRS y los parámetros se seleccionan dentro del portal (sin transferencia automática de filtros). El drill-through `R05` → `R08` se ejecuta dentro de SSRS.
