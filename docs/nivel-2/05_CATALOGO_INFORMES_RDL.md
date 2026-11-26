# 05 — Catálogo y contratos de informes paginados

**BI-OLIST Nivel 2 · 26/11/2026 · Especificación de implementación (no evidencia de ejecución)**

## Parámetros comunes
`Desde` y `Hasta`: DateTime sin hora, inclusivos, por fecha de compra; default MIN/MAX de fechas de compra observadas válidas en FactPedidos (no DimFecha calendario completo). `Desde <= Hasta`, rango histórico permitido; si inválido mostrar aviso y no ejecutar consulta de detalle (guard SQL también). Todos los filtros texto de selección única: sentinel `__TODOS__` para no filtrar, `__DESCONOCIDO__` para NULL cuando proceda; validar que no colisionan con datos reales. Los parámetros de categoría usan nombre inglés real; estado cliente/vendedor son códigos; ciudad se restringe por EstadoCliente. `TopN`: Integer 10/20/50 default 10. `DiasRetrasoMin`: Integer 1–36500 default 1. `NotaMin/NotaMax`: Float 1–5, default 1/5; se admite decimal por nota consolidada. `OrderId`: Text obligatorio no vacío; sin lista de 99k IDs. R10 usa fechas de ejecución MIN/MAX de audit.Batch.started_at. Si no hay datos, mostrar aviso, no asumir fecha del sistema. SQL explícito y parametrizado; detalle en 06.

## R01 — Resumen gerencial (Castilla)
Ruta `01_Gerencia/R01_ResumenGerencial`. Vertical A4. Desde,Hasta,EstadoCliente. Dos datasets de KPI: detalle V,E,T,F y cabecera P,C,D,S. Mostrar todos, filtros y definiciones al pie. Tendencia mensual opcional R02; botón/acción a R02 y R09 pasando parámetros comunes. Validar total y estado SP, sin duplicar hechos. C,D,S sin elegibles muestran «Sin datos».

## R02 — Consolidado mensual de ventas (Ángel)
Ruta `01_Gerencia/R02_ConsolidadoMensual`. Desde,Hasta,EstadoCliente,Categoria. Agrupar año/mes de compra con V,E,T,F, gráfico V mensual, matriz y total independiente. No sumar E ni promediar T de filas; el dataset total recalcula en todo el período. Marcar períodos parciales. Drill-down por año/mes mediante agrupación; acción R04 con rango correspondiente y categoría, si filtros no equivalentes aclararlo. Validar meses y año 2017.

## R03 — Ranking de vendedores (Cueva)
Ruta `02_Comercial/R03_RankingVendedores`. Desde,Hasta,EstadoVendedor,TopN. Vendedores por V desc, desempate seller_id asc (y vendedor_key si necesario). Mostrar ID, V,E,T,F; no inferir ubicación única del vendedor. Ranking limitado; nota «Top N, no total mercado». Mostrar total general independiente, si se incluye, bien etiquetado. Verificar TopN, empate, filtro EV y vendedor desconocido. No S,C,D,P.

## R04 — Rendimiento por categorías (Ángel)
Ruta `02_Comercial/R04_RendimientoCategorias`. Desde,Hasta,Categoria. Tabla jerárquica categoría→producto; V,E,T,F en cada nivel calculados en SQL; Top gráfico por V. Mostrar sin categoría como «Desconocida», no ocultar silenciosamente. Totales recalculados por nivel, no sumar E ni promediar T. Probar categoría con varios ítems del mismo pedido.

## R05 — Entregas retrasadas (Cueva)
Ruta `03_Operaciones/R05_EntregasRetrasadas`. Desde,Hasta,EstadoCliente,DiasRetrasoMin. Solo delivered, fecha real y estimada válidas, retraso de días calendario real−estimada >= mínimo. Tabla OrderId, estado/ciudad, compra, fecha prometida, entrega real, días retraso; ordenar retraso DESC, OrderId ASC. KPI cantidad de retrasados en el filtro y tabla por región si se necesita. Acción Go to report R08 con OrderId. No exponer datos personales. Probar entrega mismo día (no retraso) y mínimo=1.

## R06 — Satisfacción (Basualdo)
Ruta `03_Operaciones/R06_Satisfaccion`. Desde,Hasta,EstadoCliente,NotaMin,NotaMax. Una nota consolidada por pedido; tabla mensual/regional, cantidad de notas válidas y promedio; distribución por rangos [1,2),[2,3),[3,4),[4,5),5 exacto. Los rangos no son conteos de estrellas individuales. Rango inclusivo min/max y promedio recalculado. Probar decimal consolidado, NULL excluido y total con rango 1–5; no ponderar por ítems.

## R07 — Importes pagados (Poma)
Ruta `02_Comercial/R07_ImportesPagados`. Desde,Hasta,EstadoPedido. Cabecera FactPedidos; suma de `payment_value_total` de pedidos con valor observado, conteo con pago, conteo total y sin pago, por mes/estado; total recalculado. NULL no equivale a cero. No afirmar ingresos netos, medio de pago, cuotas o conciliación bancaria. Probar pedido multilínea (una sola vez) y estado cancelado.

## R08 — Ficha de pedido (Poma)
Ruta `03_Operaciones/R08_FichaPedido`. OrderId obligatorio. A4 vertical. Cabecera: order_id, estado, fecha compra/prometida/real, ubicación cliente, pago agregado, nota consolidada (nulos visibles). Detalle independiente: order_item_id, product_id, categoría, seller_id, precio y flete por línea, estado. Total de líneas separado del pago; no afirmar igualdad. Orden por order_item_id. No mostrar customer_unique_id. Si pedido existe sin líneas, mostrar cabecera y «Sin ítems»; si no existe, «Pedido no encontrado». Go to report desde R05. Probar pedido multilínea y desconocido.

## R09 — Desempeño regional (Basualdo)
Ruta `03_Operaciones/R09_DesempenoRegional`. Desde,Hasta,EstadoCliente,Ciudad (dependiente de estado; selección única). Agregar cada hecho por región de cliente de manera independiente y unir por claves del grupo; estado→ciudad con total de estado y general recalculados. Ocho indicadores, color relativo en C/S, barras V por estado. Diferenciar sin actividad vs sin elegibles. Acciones R05/R06 pasan fechas y estado, si ciudad activa advertir que se consulta todo el estado. Validar región con pocos pedidos y agrupación NULL.

## R10 — Auditoría ETL (Castilla)
Ruta `04_Auditoria/R10_AuditoriaETL`. DesdeEjecucion,HastaEjecucion,Fuente,EstadoLote. Por lote: batch_id, source_name, contract_version, estado, inicio/fin, filas leídas/aceptadas/rechazadas y conteo de rechazos registrados; indicador de conciliación solo si COMPLETE. Resumen por estado y fuente, incluir lotes históricos y distinguir reintentos; no sumar toda la historia como si fuera una sola carga. No mostrar source_file, hash si no necesario, execution_context, error_message o datos de audit.Reject. Probar COMPLETE, sin resultados y FAILED sintético solo en fixture aislada (no crear en DW real).

## Requisitos comunes de entrega
Cada RDL tiene parámetros, origen compartido, SQL versionado, visual, mensaje no-data, paginación, encabezado/pie, PDF y Excel. R01/R02/R03/R04/R06/R07/R09 deben comprobar totales; R05/R08, identidad de pedido; R10, conteos por lote. El responsable entrega capturas y resultados comparados, Poma publica. No marcar implementación por existir solo la especificación.
