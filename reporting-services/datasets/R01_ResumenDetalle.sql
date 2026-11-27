SELECT SUM(d.price) AS ventas,
       COUNT_BIG(DISTINCT d.order_id) AS entregados,
       CONVERT(float, SUM(d.price)) / NULLIF(COUNT_BIG(DISTINCT d.order_id), 0) AS ticket,
       SUM(d.freight_value) AS flete
FROM dw.FactDetallePedido AS d
JOIN dw.DimFecha AS f ON f.fecha_key = d.fecha_compra_key
JOIN dw.DimGeografiaCliente AS g ON g.geografia_cliente_key = d.geografia_cliente_key
WHERE d.order_status = 'delivered'
  AND d.fecha_compra_key <> -1
  AND f.fecha >= CAST(@Desde AS date)
  AND f.fecha <= CAST(@Hasta AS date)
  AND CAST(@Desde AS date) <= CAST(@Hasta AS date)
  AND (
      @EstadoCliente = '__TODOS__'
      OR (@EstadoCliente = '__DESCONOCIDO__' AND g.customer_state IS NULL)
      OR g.customer_state = @EstadoCliente
  );
