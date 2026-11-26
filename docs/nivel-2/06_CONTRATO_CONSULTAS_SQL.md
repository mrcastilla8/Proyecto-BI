# 06 — Contrato SQL de Reporting Services

**BI-OLIST Nivel 2 · 26/11/2026 · Especificación de implementación (no evidencia de ejecución)**

## Convenciones y guardas
Consultas de referencia **no ejecutadas** en esta sesión. Autor debe probarlas en SSMS y Report Builder contra DW auténtico y fixtures aisladas, con parámetros tipados de 05. Los ejemplos son SELECT/CTE únicamente. No crear objetos ni modificar contratos. Todos los datasets deben mantener predicados idénticos a sus totales. Los importes se comparan sin redondear, conteos exactos, ratios/promedios tolerancia absoluta 1e-7 (si la escala SQL del ticket es menor, usar división float para cotejo o precisión suficiente; no redondear a dos decimales antes de comparar). `COUNT_BIG(DISTINCT ...)` devuelve 0 si no hay filas: para V/E/F de SSAS sin filas, comprobar BLANK y representar E como NULL en el dataset de conciliación cuando no haya elegibles; en RDL separar «0 pedidos» de «Sin datos» y documentar equivalencia. P sin filas también puede ser BLANK en SSAS. No confundir los ceros reales con ausencia de población.

Filtros de compra: JOIN DimFecha, excluir -1, rango inclusivo DATE. Si se compara total sin filtro de fecha con la evidencia histórica, comprobar primero conteo de -1 y declarar diferencia de universo. Filtros de texto: `__TODOS__`, `__DESCONOCIDO__`, valor exacto; elegir parámetros disponibles por consulta SELECT DISTINCT, sin interpolar SQL. Default MIN/MAX de fechas válidas de cabecera y de ejecución de audit; si vacío no ejecutar. En Report Builder mapear cada parámetro explícitamente. No aceptar TopN fuera de 10/20/50 ni rangos inválidos. Revisar planes y tiempo sin agregar índices.

### Datasets de parámetros (ejemplos)
```sql
SELECT MIN(f.fecha) AS desde, MAX(f.fecha) AS hasta
FROM dw.FactPedidos p JOIN dw.DimFecha f ON f.fecha_key=p.fecha_compra_key
WHERE f.fecha_key<>-1;
SELECT '__TODOS__' AS valor, N'Todos' AS etiqueta
UNION ALL SELECT DISTINCT customer_state, customer_state FROM dw.DimGeografiaCliente WHERE customer_state IS NOT NULL
UNION ALL SELECT '__DESCONOCIDO__', N'Desconocido' WHERE EXISTS (SELECT 1 FROM dw.DimGeografiaCliente WHERE customer_state IS NULL);
```
Usar patrón equivalente para estado vendedor, categoría, estado pedido, fuente y estado lote. Ciudad se filtra por EstadoCliente incluyendo sentinel; cuando cambia estado restablecer Ciudad a Todos. Registrar colisiones de sentinel como error. Para detalle con parámetros inválidos no retornar filas y mostrar aviso de validación, no «0».

## R01 — dos datasets independientes

```sql
SELECT SUM(d.price) AS ventas, COUNT_BIG(DISTINCT d.order_id) AS entregados, CONVERT(float,SUM(d.price))/NULLIF(COUNT_BIG(DISTINCT d.order_id),0) AS ticket, SUM(d.freight_value) AS flete
FROM dw.FactDetallePedido d JOIN dw.DimFecha f ON f.fecha_key=d.fecha_compra_key JOIN dw.DimGeografiaCliente g ON g.geografia_cliente_key=d.geografia_cliente_key
WHERE d.order_status='delivered' AND d.fecha_compra_key <> -1 AND f.fecha >= CAST(@Desde AS date) AND f.fecha <= CAST(@Hasta AS date) AND CAST(@Desde AS date) <= CAST(@Hasta AS date) AND (@EstadoCliente = '__TODOS__' OR (@EstadoCliente = '__DESCONOCIDO__' AND g.customer_state IS NULL) OR g.customer_state = @EstadoCliente);

SELECT COUNT_BIG(*) AS pedidos,
  1.0*SUM(CASE WHEN p.order_status='delivered' AND p.fecha_entrega_real_key<>-1 AND p.fecha_entrega_estimada_key<>-1 AND p.fecha_entrega_real_key<=p.fecha_entrega_estimada_key THEN CONVERT(bigint,1) ELSE 0 END) / NULLIF(SUM(CASE WHEN p.order_status='delivered' AND p.fecha_entrega_real_key<>-1 AND p.fecha_entrega_estimada_key<>-1 THEN CONVERT(bigint,1) ELSE 0 END),0) AS puntualidad,
  AVG(CASE WHEN p.order_status='delivered' AND p.fecha_compra_key<>-1 AND p.fecha_entrega_real_key<>-1 THEN CONVERT(float,DATEDIFF_BIG(SECOND,p.order_purchase_timestamp,p.order_delivered_customer_date))/86400.0 END) AS dias,
  AVG(CONVERT(float,p.review_score)) AS nota
FROM dw.FactPedidos p JOIN dw.DimFecha f ON f.fecha_key=p.fecha_compra_key JOIN dw.DimGeografiaCliente g ON g.geografia_cliente_key=p.geografia_cliente_key
WHERE p.fecha_compra_key <> -1 AND f.fecha >= CAST(@Desde AS date) AND f.fecha <= CAST(@Hasta AS date) AND CAST(@Desde AS date) <= CAST(@Hasta AS date) AND (@EstadoCliente = '__TODOS__' OR (@EstadoCliente = '__DESCONOCIDO__' AND g.customer_state IS NULL) OR g.customer_state = @EstadoCliente);
```
No unir los hechos. Para ticket usar CONVERT(float,SUM(d.price))/NULLIF(COUNT_BIG(DISTINCT d.order_id),0) en comparación SQL/DAX de precisión completa; aplicar ese criterio a todos los datasets siguientes.

## R02 — mensual y total

```sql
SELECT GROUPING(f.anio) AS es_total, f.anio, f.mes, SUM(d.price) AS ventas, COUNT_BIG(DISTINCT d.order_id) AS entregados, CONVERT(float,SUM(d.price))/NULLIF(COUNT_BIG(DISTINCT d.order_id),0) AS ticket, SUM(d.freight_value) AS flete
FROM dw.FactDetallePedido d JOIN dw.DimFecha f ON f.fecha_key=d.fecha_compra_key JOIN dw.DimGeografiaCliente g ON g.geografia_cliente_key=d.geografia_cliente_key JOIN dw.DimProducto c ON c.producto_key=d.producto_key
WHERE d.order_status='delivered' AND d.fecha_compra_key <> -1 AND f.fecha >= CAST(@Desde AS date) AND f.fecha <= CAST(@Hasta AS date) AND CAST(@Desde AS date) <= CAST(@Hasta AS date) AND (@EstadoCliente = '__TODOS__' OR (@EstadoCliente = '__DESCONOCIDO__' AND g.customer_state IS NULL) OR g.customer_state = @EstadoCliente) AND (@Categoria = '__TODOS__' OR (@Categoria = '__DESCONOCIDO__' AND c.product_category_name_english IS NULL) OR c.product_category_name_english = @Categoria)
GROUP BY GROUPING SETS ((f.anio,f.mes),())
ORDER BY es_total,f.anio,f.mes;
```
Usar es_total=0 para gráfico y detalle, es_total=1 para pie; no sumar filas mensuales.

## R03 — Top N estable

```sql
SELECT TOP (CASE WHEN @TopN IN (10,20,50) THEN @TopN ELSE 0 END) v.seller_id, v.vendedor_key, SUM(d.price) AS ventas, COUNT_BIG(DISTINCT d.order_id) AS entregados, CONVERT(float,SUM(d.price))/NULLIF(COUNT_BIG(DISTINCT d.order_id),0) AS ticket, SUM(d.freight_value) AS flete
FROM dw.FactDetallePedido d JOIN dw.DimFecha f ON f.fecha_key=d.fecha_compra_key JOIN dw.DimVendedor v ON v.vendedor_key=d.vendedor_key
JOIN dw.DimGeografiaVendedor g ON g.geografia_vendedor_key=d.geografia_vendedor_key
WHERE d.order_status='delivered' AND d.fecha_compra_key <> -1 AND f.fecha >= CAST(@Desde AS date) AND f.fecha <= CAST(@Hasta AS date) AND CAST(@Desde AS date) <= CAST(@Hasta AS date) AND (@EstadoVendedor = '__TODOS__' OR (@EstadoVendedor = '__DESCONOCIDO__' AND g.seller_state IS NULL) OR g.seller_state = @EstadoVendedor)
GROUP BY v.seller_id,v.vendedor_key
ORDER BY ventas DESC,v.seller_id,v.vendedor_key;
```
Si se incluye total mercado, repetir predicado en dataset separado sin TOP/GROUP BY. No sumar pedidos distintos de filas.

## R04 — categoría y producto

```sql
SELECT GROUPING_ID(c.product_category_name_english,c.product_id) AS nivel, c.product_category_name_english AS categoria,c.product_id,SUM(d.price) AS ventas, COUNT_BIG(DISTINCT d.order_id) AS entregados, CONVERT(float,SUM(d.price))/NULLIF(COUNT_BIG(DISTINCT d.order_id),0) AS ticket, SUM(d.freight_value) AS flete
FROM dw.FactDetallePedido d JOIN dw.DimFecha f ON f.fecha_key=d.fecha_compra_key JOIN dw.DimProducto c ON c.producto_key=d.producto_key
WHERE d.order_status='delivered' AND d.fecha_compra_key <> -1 AND f.fecha >= CAST(@Desde AS date) AND f.fecha <= CAST(@Hasta AS date) AND CAST(@Desde AS date) <= CAST(@Hasta AS date) AND (@Categoria = '__TODOS__' OR (@Categoria = '__DESCONOCIDO__' AND c.product_category_name_english IS NULL) OR c.product_category_name_english = @Categoria)
GROUP BY GROUPING SETS ((c.product_category_name_english,c.product_id),(c.product_category_name_english),())
ORDER BY nivel,categoria,c.product_id;
```
nivel=0 producto, 1 categoría, 3 total general. Usar estos niveles para subtotales, no SUM de conteos distintos.

## R05 — retraso al día calendario

```sql
SELECT p.order_id,g.customer_state,g.customer_city,p.order_purchase_timestamp,p.order_estimated_delivery_date,p.order_delivered_customer_date,
 DATEDIFF(DAY,CAST(p.order_estimated_delivery_date AS date),CAST(p.order_delivered_customer_date AS date)) AS dias_retraso
FROM dw.FactPedidos p JOIN dw.DimFecha f ON f.fecha_key=p.fecha_compra_key JOIN dw.DimGeografiaCliente g ON g.geografia_cliente_key=p.geografia_cliente_key
WHERE p.fecha_compra_key <> -1 AND f.fecha >= CAST(@Desde AS date) AND f.fecha <= CAST(@Hasta AS date) AND CAST(@Desde AS date) <= CAST(@Hasta AS date) AND (@EstadoCliente = '__TODOS__' OR (@EstadoCliente = '__DESCONOCIDO__' AND g.customer_state IS NULL) OR g.customer_state = @EstadoCliente) AND p.order_status='delivered' AND p.fecha_entrega_estimada_key<>-1 AND p.fecha_entrega_real_key<>-1
 AND @DiasRetrasoMin BETWEEN 1 AND 36500
 AND DATEDIFF(DAY,CAST(p.order_estimated_delivery_date AS date),CAST(p.order_delivered_customer_date AS date))>=@DiasRetrasoMin
ORDER BY dias_retraso DESC,p.order_id;
```
Conteo de filas del dataset es número de pedidos retrasados en filtro. Mismo día = 0, no retrasado.

## R06 — resumen y distribución

```sql
WITH notas AS (
 SELECT f.anio,f.mes,g.customer_state,p.review_score,
 CASE WHEN p.review_score=5 THEN '5' WHEN p.review_score>=4 THEN '[4,5)' WHEN p.review_score>=3 THEN '[3,4)' WHEN p.review_score>=2 THEN '[2,3)' ELSE '[1,2)' END AS rango
 FROM dw.FactPedidos p JOIN dw.DimFecha f ON f.fecha_key=p.fecha_compra_key JOIN dw.DimGeografiaCliente g ON g.geografia_cliente_key=p.geografia_cliente_key
 WHERE p.fecha_compra_key <> -1 AND f.fecha >= CAST(@Desde AS date) AND f.fecha <= CAST(@Hasta AS date) AND CAST(@Desde AS date) <= CAST(@Hasta AS date) AND (@EstadoCliente = '__TODOS__' OR (@EstadoCliente = '__DESCONOCIDO__' AND g.customer_state IS NULL) OR g.customer_state = @EstadoCliente) AND @NotaMin>=1 AND @NotaMax<=5 AND @NotaMin<=@NotaMax AND p.review_score BETWEEN @NotaMin AND @NotaMax
)
SELECT GROUPING_ID(anio,mes,customer_state,rango) AS nivel,anio,mes,customer_state,rango,COUNT_BIG(*) AS notas_validas,AVG(CONVERT(float,review_score)) AS nota
FROM notas GROUP BY GROUPING SETS ((anio,mes),(customer_state),(rango),())
ORDER BY nivel,anio,mes,customer_state,rango;
```
nivel=3 mes, 13 estado, 14 rango, 15 total. No sumar niveles entre sí. R06 con rango 1–5 concilia promedio S; rango restringido es métrica de subconjunto, no equivalente a S sin filtro.

## R07 — importes pagados

```sql
SELECT GROUPING_ID(f.anio,f.mes,p.order_status) AS nivel,f.anio,f.mes,p.order_status,COUNT_BIG(*) AS pedidos,COUNT_BIG(p.payment_value_total) AS con_pago,COUNT_BIG(*)-COUNT_BIG(p.payment_value_total) AS sin_pago,SUM(p.payment_value_total) AS importe_observado
FROM dw.FactPedidos p JOIN dw.DimFecha f ON f.fecha_key=p.fecha_compra_key
WHERE p.fecha_compra_key <> -1 AND f.fecha >= CAST(@Desde AS date) AND f.fecha <= CAST(@Hasta AS date) AND CAST(@Desde AS date) <= CAST(@Hasta AS date) AND (@EstadoPedido = '__TODOS__' OR (@EstadoPedido = '__DESCONOCIDO__' AND p.order_status IS NULL) OR p.order_status = @EstadoPedido)
GROUP BY GROUPING SETS ((f.anio,f.mes,p.order_status),(f.anio,f.mes),())
ORDER BY nivel,f.anio,f.mes,p.order_status;
```
nivel=0 detalle mensual/estado, 1 mes, 7 total. NULL de suma si no hay pagos observados.

## R08 — ficha, datasets cabecera y detalle

```sql
SELECT p.order_id,p.order_status,p.order_purchase_timestamp,p.order_estimated_delivery_date,p.order_delivered_customer_date,g.customer_state,g.customer_city,p.payment_value_total,p.review_score
FROM dw.FactPedidos p JOIN dw.DimGeografiaCliente g ON g.geografia_cliente_key=p.geografia_cliente_key
WHERE p.order_id=@OrderId AND LEN(@OrderId) BETWEEN 1 AND 64;
SELECT d.order_id,d.order_item_id,c.product_id,c.product_category_name_english,v.seller_id,d.price,d.freight_value,d.order_status
FROM dw.FactDetallePedido d JOIN dw.DimProducto c ON c.producto_key=d.producto_key JOIN dw.DimVendedor v ON v.vendedor_key=d.vendedor_key
WHERE d.order_id=@OrderId AND LEN(@OrderId) BETWEEN 1 AND 64 ORDER BY d.order_item_id;
```
Sin cabecera: no encontrado. Totales del detalle solo sobre sus filas; no multiplicar pago o nota.

## R09 — agrupación independiente y unión segura

```sql
WITH d_agg AS (
 SELECT GROUPING_ID(g.customer_state,g.customer_city) AS nivel,g.customer_state AS estado,g.customer_city AS ciudad,SUM(d.price) AS ventas, COUNT_BIG(DISTINCT d.order_id) AS entregados, CONVERT(float,SUM(d.price))/NULLIF(COUNT_BIG(DISTINCT d.order_id),0) AS ticket, SUM(d.freight_value) AS flete
 FROM dw.FactDetallePedido d JOIN dw.DimFecha f ON f.fecha_key=d.fecha_compra_key JOIN dw.DimGeografiaCliente g ON g.geografia_cliente_key=d.geografia_cliente_key WHERE d.order_status='delivered' AND d.fecha_compra_key <> -1 AND f.fecha >= CAST(@Desde AS date) AND f.fecha <= CAST(@Hasta AS date) AND CAST(@Desde AS date) <= CAST(@Hasta AS date) AND (@EstadoCliente = '__TODOS__' OR (@EstadoCliente = '__DESCONOCIDO__' AND g.customer_state IS NULL) OR g.customer_state = @EstadoCliente) AND (@Ciudad = '__TODOS__' OR (@Ciudad = '__DESCONOCIDO__' AND g.customer_city IS NULL) OR g.customer_city = @Ciudad)
 GROUP BY GROUPING SETS ((g.customer_state,g.customer_city),(g.customer_state),())
), p_agg AS (
 SELECT GROUPING_ID(g.customer_state,g.customer_city) AS nivel,g.customer_state AS estado,g.customer_city AS ciudad,COUNT_BIG(*) AS pedidos,
  1.0*SUM(CASE WHEN p.order_status='delivered' AND p.fecha_entrega_real_key<>-1 AND p.fecha_entrega_estimada_key<>-1 AND p.fecha_entrega_real_key<=p.fecha_entrega_estimada_key THEN CONVERT(bigint,1) ELSE 0 END) / NULLIF(SUM(CASE WHEN p.order_status='delivered' AND p.fecha_entrega_real_key<>-1 AND p.fecha_entrega_estimada_key<>-1 THEN CONVERT(bigint,1) ELSE 0 END),0) AS puntualidad,
  AVG(CASE WHEN p.order_status='delivered' AND p.fecha_compra_key<>-1 AND p.fecha_entrega_real_key<>-1 THEN CONVERT(float,DATEDIFF_BIG(SECOND,p.order_purchase_timestamp,p.order_delivered_customer_date))/86400.0 END) AS dias,
  AVG(CONVERT(float,p.review_score)) AS nota
 FROM dw.FactPedidos p JOIN dw.DimFecha f ON f.fecha_key=p.fecha_compra_key JOIN dw.DimGeografiaCliente g ON g.geografia_cliente_key=p.geografia_cliente_key WHERE p.fecha_compra_key <> -1 AND f.fecha >= CAST(@Desde AS date) AND f.fecha <= CAST(@Hasta AS date) AND CAST(@Desde AS date) <= CAST(@Hasta AS date) AND (@EstadoCliente = '__TODOS__' OR (@EstadoCliente = '__DESCONOCIDO__' AND g.customer_state IS NULL) OR g.customer_state = @EstadoCliente) AND (@Ciudad = '__TODOS__' OR (@Ciudad = '__DESCONOCIDO__' AND g.customer_city IS NULL) OR g.customer_city = @Ciudad)
 GROUP BY GROUPING SETS ((g.customer_state,g.customer_city),(g.customer_state),())
)
SELECT COALESCE(d.nivel,p.nivel) AS nivel,COALESCE(d.estado,p.estado) AS estado,COALESCE(d.ciudad,p.ciudad) AS ciudad,d.ventas,d.entregados,d.ticket,d.flete,p.pedidos,p.puntualidad,p.dias,p.nota
FROM d_agg d FULL OUTER JOIN p_agg p ON d.nivel=p.nivel AND (d.estado=p.estado OR (d.estado IS NULL AND p.estado IS NULL)) AND (d.ciudad=p.ciudad OR (d.ciudad IS NULL AND p.ciudad IS NULL))
ORDER BY nivel,estado,ciudad;
```
nivel=0 ciudad, 1 estado, 3 total. Distinguir NULL real y subtotal por nivel; no usar JOIN directo detalle→cabecera. Si estado o ciudad sin filas de un hecho, mantener NULL.

## R10 — auditoría sin información sensible

```sql
WITH rechazos AS (SELECT batch_id,COUNT_BIG(*) AS registrados FROM audit.Reject GROUP BY batch_id)
SELECT b.batch_id,b.source_name,b.contract_version,b.status,b.started_at,b.finished_at,b.rows_read,b.rows_accepted,b.rows_rejected,COALESCE(r.registrados,0) AS rechazos_registrados,
 CASE WHEN b.status='COMPLETE' THEN CASE WHEN b.rows_read=b.rows_accepted+b.rows_rejected AND b.rows_rejected=COALESCE(r.registrados,0) THEN 'CONCILIADO' ELSE 'REVISAR' END ELSE 'NO_TERMINAL_O_FALLIDO' END AS control
FROM audit.Batch b LEFT JOIN rechazos r ON r.batch_id=b.batch_id
WHERE CAST(b.started_at AS date) BETWEEN CAST(@DesdeEjecucion AS date) AND CAST(@HastaEjecucion AS date)
 AND CAST(@DesdeEjecucion AS date)<=CAST(@HastaEjecucion AS date) AND (@Fuente = '__TODOS__' OR (@Fuente = '__DESCONOCIDO__' AND b.source_name IS NULL) OR b.source_name = @Fuente) AND (@EstadoLote = '__TODOS__' OR (@EstadoLote = '__DESCONOCIDO__' AND b.status IS NULL) OR b.status = @EstadoLote)
ORDER BY b.started_at DESC,b.batch_id DESC;
```
REVISAR si diferencia entre contador y registros; no inventar causa. No consultar texto de rechazos. Resumen de lotes por estado/fuente con conteos, no sumar reintentos como carga actual.
