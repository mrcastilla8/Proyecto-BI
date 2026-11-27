SELECT p.order_id,g.customer_state,g.customer_city,p.order_purchase_timestamp,p.order_estimated_delivery_date,p.order_delivered_customer_date,
 DATEDIFF(DAY,CAST(p.order_estimated_delivery_date AS date),CAST(p.order_delivered_customer_date AS date)) AS dias_retraso
FROM dw.FactPedidos p JOIN dw.DimFecha f ON f.fecha_key=p.fecha_compra_key JOIN dw.DimGeografiaCliente g ON g.geografia_cliente_key=p.geografia_cliente_key
WHERE p.fecha_compra_key <> -1 AND f.fecha >= CAST(@Desde AS date) AND f.fecha <= CAST(@Hasta AS date) AND CAST(@Desde AS date) <= CAST(@Hasta AS date) AND (@EstadoCliente = '__TODOS__' OR (@EstadoCliente = '__DESCONOCIDO__' AND g.customer_state IS NULL) OR g.customer_state = @EstadoCliente) AND p.order_status='delivered' AND p.fecha_entrega_estimada_key<>-1 AND p.fecha_entrega_real_key<>-1
 AND @DiasRetrasoMin BETWEEN 1 AND 36500
 AND DATEDIFF(DAY,CAST(p.order_estimated_delivery_date AS date),CAST(p.order_delivered_customer_date AS date))>=@DiasRetrasoMin
ORDER BY dias_retraso DESC,p.order_id;
