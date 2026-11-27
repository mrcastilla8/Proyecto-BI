SELECT COUNT_BIG(*) AS pedidos,
       1.0 * SUM(CASE WHEN p.order_status = 'delivered' AND p.fecha_entrega_real_key <> -1 AND p.fecha_entrega_estimada_key <> -1 AND p.fecha_entrega_real_key <= p.fecha_entrega_estimada_key THEN CONVERT(bigint, 1) ELSE 0 END)
       / NULLIF(SUM(CASE WHEN p.order_status = 'delivered' AND p.fecha_entrega_real_key <> -1 AND p.fecha_entrega_estimada_key <> -1 THEN CONVERT(bigint, 1) ELSE 0 END), 0) AS puntualidad,
       AVG(CASE WHEN p.order_status = 'delivered' AND p.fecha_compra_key <> -1 AND p.fecha_entrega_real_key <> -1 THEN CONVERT(float, DATEDIFF_BIG(SECOND, p.order_purchase_timestamp, p.order_delivered_customer_date)) / 86400.0 END) AS dias,
       AVG(CONVERT(float, p.review_score)) AS nota
FROM dw.FactPedidos AS p
JOIN dw.DimFecha AS f ON f.fecha_key = p.fecha_compra_key
JOIN dw.DimGeografiaCliente AS g ON g.geografia_cliente_key = p.geografia_cliente_key
WHERE p.fecha_compra_key <> -1
  AND f.fecha >= CAST(@Desde AS date)
  AND f.fecha <= CAST(@Hasta AS date)
  AND CAST(@Desde AS date) <= CAST(@Hasta AS date)
  AND (
      @EstadoCliente = '__TODOS__'
      OR (@EstadoCliente = '__DESCONOCIDO__' AND g.customer_state IS NULL)
      OR g.customer_state = @EstadoCliente
  );
