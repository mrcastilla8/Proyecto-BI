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
