WITH Limites AS (
    SELECT MIN(f.fecha) AS fecha_minima, MAX(f.fecha) AS fecha_maxima
    FROM dw.FactPedidos AS p
    JOIN dw.DimFecha AS f ON f.fecha_key = p.fecha_compra_key
    WHERE f.fecha_key <> -1
)
SELECT GROUPING_ID(f.anio, f.mes) AS nivel,
       f.anio, f.mes,
       SUM(d.price) AS ventas,
       COUNT_BIG(DISTINCT d.order_id) AS entregados,
       CONVERT(float, SUM(d.price)) / NULLIF(COUNT_BIG(DISTINCT d.order_id), 0) AS ticket,
       SUM(d.freight_value) AS flete,
       CASE WHEN GROUPING(f.mes) = 0
             AND (DATEFROMPARTS(f.anio, f.mes, 1) < CAST(@Desde AS date)
                  OR EOMONTH(DATEFROMPARTS(f.anio, f.mes, 1)) > CAST(@Hasta AS date)
                  OR DATEFROMPARTS(f.anio, f.mes, 1) < MIN(l.fecha_minima)
                  OR EOMONTH(DATEFROMPARTS(f.anio, f.mes, 1)) > MAX(l.fecha_maxima))
            THEN 1 ELSE 0 END AS mes_parcial
FROM dw.FactDetallePedido AS d
JOIN dw.DimFecha AS f ON f.fecha_key = d.fecha_compra_key
JOIN dw.DimGeografiaCliente AS g ON g.geografia_cliente_key = d.geografia_cliente_key
JOIN dw.DimProducto AS c ON c.producto_key = d.producto_key
CROSS JOIN Limites AS l
WHERE d.order_status = 'delivered'
  AND d.fecha_compra_key <> -1
  AND f.fecha >= CAST(@Desde AS date)
  AND f.fecha <= CAST(@Hasta AS date)
  AND CAST(@Desde AS date) <= CAST(@Hasta AS date)
  AND (
      @EstadoCliente = '__TODOS__'
      OR (@EstadoCliente = '__DESCONOCIDO__' AND g.customer_state IS NULL)
      OR g.customer_state = @EstadoCliente
  )
  AND (
      @Categoria = '__TODOS__'
      OR (@Categoria = '__DESCONOCIDO__' AND c.product_category_name_english IS NULL)
      OR c.product_category_name_english = @Categoria
  )
GROUP BY GROUPING SETS ((f.anio, f.mes), (f.anio), ())
HAVING COUNT_BIG(*) > 0
ORDER BY nivel DESC, f.anio, f.mes;
