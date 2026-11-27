WITH Limites AS (
    SELECT MIN(f.fecha) AS desde, MAX(f.fecha) AS hasta
    FROM dw.FactPedidos AS p
    JOIN dw.DimFecha AS f ON f.fecha_key = p.fecha_compra_key
    WHERE f.fecha_key <> -1
),
Fechas AS (
    SELECT f.fecha_key
    FROM dw.DimFecha AS f
    CROSS JOIN Limites AS l
    WHERE f.fecha_key <> -1
      AND CAST(@Desde AS date) >= l.desde
      AND CAST(@Hasta AS date) <= l.hasta
      AND CAST(@Desde AS date) <= CAST(@Hasta AS date)
      AND f.fecha BETWEEN CAST(@Desde AS date) AND CAST(@Hasta AS date)
),
Geografia AS (
    SELECT g.geografia_cliente_key, g.customer_state AS estado, g.customer_city AS ciudad
    FROM dw.DimGeografiaCliente AS g
    WHERE (@EstadoCliente = '__TODOS__'
           OR (@EstadoCliente = '__DESCONOCIDO__' AND g.customer_state IS NULL)
           OR g.customer_state = @EstadoCliente)
      AND (@Ciudad = '__TODOS__'
           OR (@Ciudad = '__DESCONOCIDO__' AND g.customer_city IS NULL)
           OR g.customer_city = @Ciudad)
),
Detalle AS (
    SELECT GROUPING_ID(g.estado, g.ciudad) AS nivel, g.estado, g.ciudad,
           SUM(d.price) AS ventas,
           COUNT_BIG(DISTINCT d.order_id) AS entregados,
           CONVERT(float, SUM(d.price)) / NULLIF(COUNT_BIG(DISTINCT d.order_id), 0) AS ticket,
           SUM(d.freight_value) AS flete
    FROM dw.FactDetallePedido AS d
    JOIN Fechas AS f ON f.fecha_key = d.fecha_compra_key
    JOIN Geografia AS g ON g.geografia_cliente_key = d.geografia_cliente_key
    WHERE d.order_status = 'delivered'
    GROUP BY GROUPING SETS ((g.estado, g.ciudad), (g.estado), ())
    HAVING COUNT_BIG(*) > 0
),
Pedidos AS (
    SELECT GROUPING_ID(g.estado, g.ciudad) AS nivel, g.estado, g.ciudad,
           COUNT_BIG(*) AS pedidos,
           AVG(CASE
               WHEN p.order_status = 'delivered'
                AND p.fecha_entrega_real_key <> -1 AND p.fecha_entrega_estimada_key <> -1
               THEN CONVERT(float, CASE
                   WHEN p.fecha_entrega_real_key <= p.fecha_entrega_estimada_key THEN 1
                   ELSE 0
               END)
           END) AS puntualidad,
           AVG(CASE
               WHEN p.order_status = 'delivered' AND p.fecha_entrega_real_key <> -1
               THEN CONVERT(float, DATEDIFF_BIG(SECOND, p.order_purchase_timestamp,
                                               p.order_delivered_customer_date)) / 86400.0
           END) AS dias,
           AVG(CONVERT(float, p.review_score)) AS nota
    FROM dw.FactPedidos AS p
    JOIN Fechas AS f ON f.fecha_key = p.fecha_compra_key
    JOIN Geografia AS g ON g.geografia_cliente_key = p.geografia_cliente_key
    GROUP BY GROUPING SETS ((g.estado, g.ciudad), (g.estado), ())
    HAVING COUNT_BIG(*) > 0
),
Resultados AS (
    SELECT COALESCE(d.nivel, p.nivel) AS nivel,
           COALESCE(d.estado, p.estado) AS estado,
           COALESCE(d.ciudad, p.ciudad) AS ciudad,
           d.ventas, d.entregados, d.ticket, d.flete, p.pedidos, p.puntualidad, p.dias, p.nota
    FROM Detalle AS d
    FULL OUTER JOIN Pedidos AS p ON d.nivel = p.nivel
      AND (d.estado = p.estado OR (d.estado IS NULL AND p.estado IS NULL))
      AND (d.ciudad = p.ciudad OR (d.ciudad IS NULL AND p.ciudad IS NULL))
)
SELECT nivel, estado, ciudad, ventas, entregados, ticket, flete, pedidos, puntualidad, dias, nota,
       CASE WHEN nivel = 1 THEN CONVERT(float, ventas) /
           NULLIF(MAX(CASE WHEN nivel = 1 THEN CONVERT(float, ventas) END) OVER (), 0)
       END AS ventas_relativas,
       MAX(CASE WHEN nivel = 3 THEN puntualidad END) OVER () AS puntualidad_total,
       MAX(CASE WHEN nivel = 3 THEN nota END) OVER () AS nota_total
FROM Resultados
ORDER BY nivel DESC, estado, ciudad;
