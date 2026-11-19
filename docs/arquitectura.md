# Arquitectura

`CSV Olist → SSIS ingesta → SQL Server BI_OLIST.stg → SSIS transformación → BI_OLIST.dw → SSAS Tabular → Power BI Live`. El DDL SQL de `audit`, `stg` y `dw` está implementado y fue ejecutado localmente en SQL Server 2025 Express 17.0.1000.7. Los CSV fueron perfilados localmente, pero no cargados al esquema. SSIS, SSAS y Power BI siguen pendientes de integración. Servidor, instancia, puerto y credenciales son parámetros locales; no se requiere el equipo ajeno.

## Granos físicos implementados (contrato aún provisional)
- `dw.FactPedidos`: una fila por `order_id`; estado/fechas, cliente/geografía, pago agregado y reseña consolidada (media de notas válidas por pedido, propuesta).
- `dw.FactDetallePedido`: una fila por `(order_id, order_item_id)`; producto, vendedor, cliente/geografía, compra, precio, flete y estado.
- Agregar pagos y reviews por `order_id` antes de integrarlos. `customer_unique_id` identifica cliente analítico, no es `customer_id`.
- Dimensiones: DimFecha (key YYYYMMDD), DimCliente, DimProducto, DimVendedor y geografías separadas cliente/vendedor. `order_id` degenerado en ambos hechos. Sin relación directa entre hechos ni filtros bidireccionales generales.
- Conteos de pedidos por producto/vendedor: DISTINCTCOUNT desde FactDetallePedido en el contexto filtrado.
- Geolocation puede ir a staging, pero no unir por prefijo postal sin resolver multiplicidad y aprobarlo.

SQL usa claves sustitutas/naturales únicas, FK, DECIMAL, DATETIME2/DATE, desconocidos explícitos y controles de duplicados. Los scripts 00–06 son reejecutables y se probaron en una base inicialmente inexistente; la segunda ejecución no borró datos. Los hechos están vacíos y los componentes SSIS son responsables de la carga. Developer es opción académica/no productiva cuando se requiere SSAS; Express no lo incluye, SSAS se instala aparte. Registrar versiones/proveedores/extensiones realmente verificados. No exponer SQL/SSAS a internet; Power BI Live requiere acceso real y seguro al servicio.
