# Contrato semántico de métricas v1

Las métricas de `contracts/metricas.v1.json` son propuestas pendientes de validación. Importes nominales BRL observados no significan utilidad, margen ni facturación neta. No se incluyen medidas DAX implementadas ni resultados calculados.

## Tiempo y relaciones SSAS propuestas

Una `DimFecha` con roles de compra, entrega estimada y entrega real: relación de compra activa al campo de compra de cada hecho; relaciones de estimada y real inactivas. Medidas que evalúan una sola fecha alternativa activan su relación con `USERELATIONSHIP`. Si páginas/filtros requieren seleccionar simultáneamente roles de fecha, usar dimensiones de fecha duplicadas por rol y relaciones activas claras. Mantener dirección dimensión→hecho; no relacionar hechos entre sí ni usar bidireccionalidad general. FKs fecha opcionales apuntan a miembro desconocido y cada medida temporal excluye NULL/invalid date explícitamente.

## Definiciones y conciliación SQL propuesta

Usar los mismos predicados de estado y elegibilidad en DAX y SQL. Alias `dw.FactPedidos p`, `dw.FactDetallePedido d`; nombres de columnas físicos son provisionales y deben alinearse con DDL aprobado.

| Métrica | Grano y contexto | SQL de conciliación propuesto |
|---|---|---|
| Ventas de productos entregados | Líneas entregadas, por producto/vendedor/compra | `SELECT SUM(d.price) FROM dw.FactDetallePedido d WHERE d.order_status='delivered';` |
| Pedidos entregados con ítems | DISTINCTCOUNT de pedido desde el hecho de detalle | `SELECT COUNT(DISTINCT d.order_id) FROM dw.FactDetallePedido d WHERE d.order_status='delivered';` |
| Pedidos totales | Una fila de FactPedidos, incluye sin líneas | `SELECT COUNT_BIG(*) FROM dw.FactPedidos;` |
| Ticket promedio de productos entregados | Ventas de líneas / pedidos con al menos una línea entregada | `SELECT SUM(d.price)/NULLIF(COUNT(DISTINCT d.order_id),0) FROM dw.FactDetallePedido d WHERE d.order_status='delivered';` |
| Flete de pedidos entregados | Suma de flete de líneas entregadas | `SELECT SUM(d.freight_value) FROM dw.FactDetallePedido d WHERE d.order_status='delivered';` |
| % entregas a tiempo | Pedidos entregados con fechas estimada y real válidas; numerator real ≤ estimada | `SELECT 1.0*SUM(CASE WHEN p.order_delivered_customer_date<=p.order_estimated_delivery_date THEN 1 ELSE 0 END)/NULLIF(COUNT_BIG(*),0) FROM dw.FactPedidos p WHERE p.order_status='delivered' AND p.order_delivered_customer_date IS NOT NULL AND p.order_estimated_delivery_date IS NOT NULL;` |
| Días promedio de entrega | Compra a entrega real; entregados con ambas fechas válidas | `SELECT AVG(CAST(DATEDIFF_BIG(SECOND,p.order_purchase_timestamp,p.order_delivered_customer_date) AS decimal(19,4))/86400.0) FROM dw.FactPedidos p WHERE p.order_status='delivered' AND p.order_purchase_timestamp IS NOT NULL AND p.order_delivered_customer_date IS NOT NULL;` |
| Calificación promedio | Una nota consolidada válida por pedido, no por línea | `SELECT AVG(CAST(p.review_score AS decimal(9,4))) FROM dw.FactPedidos p WHERE p.review_score IS NOT NULL;` |

Cada consulta debe ampliarse con los filtros equivalentes del visual (incluidos los filtros producto/vendedor/geografía/fecha aplicables); guardar SQL, filtro, resultado y versión de datos como evidencia real. No comparar métricas con contextos distintos. Para venta/producto y vendedor siempre se parte de `FactDetallePedido`; conteo por producto/vendedor es `COUNT(DISTINCT order_id)` en ese contexto. Pedidos totales parten de `FactPedidos`, para no excluir órdenes sin líneas. Indicadores de entrega excluyen otros estados y fechas no elegibles. Reseña se agrega por pedido antes de entrar a FactPedidos, evitando ponderación por cantidad de líneas.

Las consultas son especificaciones de conciliación, no DDL garantizado: el equipo de Castilla confirmará nombres/tipos/grano y la lógica de fecha/estado tras inspección de CSV reales y revisión de los afectados. Cualquier discrepancia semántica exige issue/ADR y aprobación antes de cambiar el contrato.
