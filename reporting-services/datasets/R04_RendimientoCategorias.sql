SELECT GROUPING_ID(c.product_category_name_english, c.product_id) AS nivel,
       c.product_category_name_english AS categoria,
       c.product_id,
       SUM(d.price) AS ventas,
       COUNT_BIG(DISTINCT d.order_id) AS entregados,
       CONVERT(float, SUM(d.price)) / NULLIF(COUNT_BIG(DISTINCT d.order_id), 0) AS ticket,
       SUM(d.freight_value) AS flete
FROM dw.FactDetallePedido AS d
JOIN dw.DimFecha AS f ON f.fecha_key = d.fecha_compra_key
JOIN dw.DimProducto AS c ON c.producto_key = d.producto_key
WHERE d.order_status = 'delivered'
  AND d.fecha_compra_key <> -1
  AND f.fecha >= CAST(@Desde AS date)
  AND f.fecha <= CAST(@Hasta AS date)
  AND CAST(@Desde AS date) <= CAST(@Hasta AS date)
  AND (
      @Categoria = '__TODOS__'
      OR (@Categoria = '__DESCONOCIDO__' AND c.product_category_name_english IS NULL)
      OR c.product_category_name_english = @Categoria
  )
GROUP BY GROUPING SETS ((c.product_category_name_english, c.product_id), (c.product_category_name_english), ())
ORDER BY nivel DESC, categoria, c.product_id;
