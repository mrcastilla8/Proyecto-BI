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

## Nivel 2 — Ampliación en capa de consumo (pendiente de aprobación e implementación)
Según [ADR-0002](decisiones/ADR-0002-nivel-2-powerbi-reporting-services.md) y [01_ARQUITECTURA_INTEGRADA.md](nivel-2/01_ARQUITECTURA_INTEGRADA.md), el Nivel 2 mantiene intactos `stg`, `dw`, `audit`, SSIS y SSAS Tabular (`Model.bim` y 8 medidas DAX) y amplía únicamente la capa de consumo:
- **Power BI Desktop Live:** 15 páginas totales (8 principales, 4 tooltips y 3 drill-through) conectadas en vivo a `BI_OLIST_Tabular`, sin modelo local ni medidas DAX adicionales.
- **SSRS 2022 Developer (Native Mode):** 10 informes RDL (`R01`–`R10`) con catálogo interno separado (`ReportServer`/`ReportServerTempDB`) en la instancia SQL Server 2025 Developer (sujeto a validación en `G0`). Consumen `BI_OLIST.dw` (y `audit` exclusivamente agregado en `R10`) mediante consultas `SELECT` parametrizadas de solo lectura y origen compartido dedicado.
- **Integración Power BI → SSRS:** enlaces URL fijos hacia el portal SSRS; la selección de parámetros se realiza dentro del portal SSRS sin transferencia automática de filtros desde Power BI.
