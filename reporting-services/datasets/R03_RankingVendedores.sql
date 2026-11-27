SELECT TOP (CASE WHEN @TopN IN (10,20,50) THEN @TopN ELSE 0 END) v.seller_id, v.vendedor_key, SUM(d.price) AS ventas, COUNT_BIG(DISTINCT d.order_id) AS entregados, CONVERT(float,SUM(d.price))/NULLIF(COUNT_BIG(DISTINCT d.order_id),0) AS ticket, SUM(d.freight_value) AS flete
FROM dw.FactDetallePedido d JOIN dw.DimFecha f ON f.fecha_key=d.fecha_compra_key JOIN dw.DimVendedor v ON v.vendedor_key=d.vendedor_key
JOIN dw.DimGeografiaVendedor g ON g.geografia_vendedor_key=d.geografia_vendedor_key
WHERE d.order_status='delivered' AND d.fecha_compra_key <> -1 AND f.fecha >= CAST(@Desde AS date) AND f.fecha <= CAST(@Hasta AS date) AND CAST(@Desde AS date) <= CAST(@Hasta AS date) AND (@EstadoVendedor = '__TODOS__' OR (@EstadoVendedor = '__DESCONOCIDO__' AND g.seller_state IS NULL) OR g.seller_state = @EstadoVendedor)
GROUP BY v.seller_id,v.vendedor_key
ORDER BY ventas DESC,v.seller_id,v.vendedor_key;
