# Contrato semántico de métricas v1

Definiciones propuestas en `contracts/metricas.v1.json`; BRL. Valores observados no son utilidad, margen ni facturación neta. Sin resultados hasta probar datos reales.

- **Ventas de productos entregados:** suma de `price` de líneas con `order_status='delivered'`; excluye flete.
- **Pedidos entregados con ítems:** DISTINCTCOUNT de `order_id` en líneas entregadas. **Pedidos totales** cuenta FactPedidos, incluidos otros estados y sin líneas.
- **Ticket promedio de productos entregados:** ventas entregadas / pedidos entregados con ítems, división segura.
- **Flete de pedidos entregados:** suma de `freight_value` en líneas entregadas.
- **% entregas a tiempo:** pedidos entregados con ambas fechas válidas y real <= estimada / entregados con ambas fechas válidas. Excluye cancelados, no entregados y nulos.
- **Días de entrega:** promedio de compra a entrega real, pedidos entregados con fechas válidas.
- **Calificación promedio:** promedio de nota agregada una vez por pedido con review válida; no ponderar por líneas.

Por vendedor/producto, conteo pedido viene de FactDetallePedido bajo filtro correcto. DAX y SQL se comparan con filtros equivalentes.
