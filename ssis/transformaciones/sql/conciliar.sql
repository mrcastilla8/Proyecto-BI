-- Solo lectura del DW/audit/stg. Ejecutar sin otras publicaciones en curso.
SET NOCOUNT ON;
DECLARE @Ejecucion bigint, @Lotes nvarchar(400);
SELECT TOP (1) @Ejecucion=batch_id, @Lotes=execution_context
FROM audit.Batch WHERE source_name=N'DW.Transformacion' AND status='COMPLETE'
ORDER BY finished_at DESC, batch_id DESC;
IF @Ejecucion IS NULL THROW 52020, N'No hay una publicación de transformación COMPLETE.', 1;

DECLARE @Orders bigint = JSON_VALUE(@Lotes, '$.Orders'),
        @Items bigint = JSON_VALUE(@Lotes, '$.OrderItems'),
        @Payments bigint = JSON_VALUE(@Lotes, '$.OrderPayments'),
        @Reviews bigint = JSON_VALUE(@Lotes, '$.OrderReviews');

IF (SELECT COUNT_BIG(*) FROM dw.FactPedidos) <> (SELECT COUNT_BIG(*) FROM stg.Orders WHERE batch_id=@Orders)
   OR (SELECT COUNT_BIG(*) FROM dw.FactDetallePedido) <> (SELECT COUNT_BIG(*) FROM stg.OrderItems WHERE batch_id=@Items)
    THROW 52021, N'Los conteos de los hechos difieren de staging.', 1;

;WITH Pagos AS (
    SELECT order_id, CONVERT(decimal(19,4), SUM(payment_value)) AS total
    FROM stg.OrderPayments WHERE batch_id=@Payments GROUP BY order_id
), Resenas AS (
    SELECT order_id, CONVERT(decimal(9,4), AVG(CONVERT(decimal(9,4), review_score))) AS promedio
    FROM stg.OrderReviews WHERE batch_id=@Reviews AND review_score BETWEEN 1 AND 5 GROUP BY order_id
)
SELECT p.order_id, p.order_status, p.order_purchase_timestamp,
       p.order_estimated_delivery_date, p.order_delivered_customer_date,
       a.total, r.promedio
INTO #PedidosEsperados
FROM stg.Orders AS p
LEFT JOIN Pagos AS a ON a.order_id=p.order_id
LEFT JOIN Resenas AS r ON r.order_id=p.order_id
WHERE p.batch_id=@Orders;

IF EXISTS (
    SELECT order_id, order_status, order_purchase_timestamp, order_estimated_delivery_date,
           order_delivered_customer_date, total, promedio FROM #PedidosEsperados
    EXCEPT
    SELECT order_id, order_status, order_purchase_timestamp, order_estimated_delivery_date,
           order_delivered_customer_date, payment_value_total, review_score FROM dw.FactPedidos
)
    THROW 52022, N'Hay diferencias en pedidos, fechas, pagos o reseñas.', 1;

IF EXISTS (
    SELECT l.order_id, l.order_item_id, l.price, l.freight_value, p.order_status,
           COALESCE(CONVERT(int, CONVERT(char(8), p.order_purchase_timestamp, 112)), -1)
    FROM stg.OrderItems AS l JOIN #PedidosEsperados AS p ON p.order_id=l.order_id
    WHERE l.batch_id=@Items
    EXCEPT
    SELECT order_id, order_item_id, price, freight_value, order_status, fecha_compra_key
    FROM dw.FactDetallePedido
)
    THROW 52023, N'Hay diferencias en líneas, importes, estado o fecha de compra.', 1;

IF EXISTS (
    SELECT 1 FROM dw.FactDetallePedido AS d LEFT JOIN dw.FactPedidos AS p ON p.order_id=d.order_id
    WHERE p.order_id IS NULL OR p.cliente_key<>d.cliente_key OR p.geografia_cliente_key<>d.geografia_cliente_key
) OR EXISTS (
    SELECT 1 FROM dw.FactPedidos
    WHERE fecha_compra_key<>COALESCE(CONVERT(int, CONVERT(char(8), order_purchase_timestamp, 112)), -1)
       OR fecha_entrega_estimada_key<>COALESCE(CONVERT(int, CONVERT(char(8), order_estimated_delivery_date, 112)), -1)
       OR fecha_entrega_real_key<>COALESCE(CONVERT(int, CONVERT(char(8), order_delivered_customer_date, 112)), -1)
)
    THROW 52024, N'Un hecho tiene claves incoherentes para pedido, cliente, geografía o fecha.', 1;

SELECT batch_id, status, rows_read, rows_accepted, rows_rejected, rejection_records
FROM audit.vw_BatchStatus WHERE batch_id=@Ejecucion;

SELECT COUNT_BIG(*) AS pedidos, SUM(payment_value_total) AS pagos,
       COUNT_BIG(review_score) AS pedidos_con_resena, AVG(review_score) AS calificacion_media
FROM dw.FactPedidos;
SELECT COUNT_BIG(*) AS lineas, SUM(price) AS precio, SUM(freight_value) AS flete FROM dw.FactDetallePedido;

-- Comparar esta cuadrícula entre ejecuciones. Las claves sustitutas forman parte de la huella.
SELECT tabla, CONVERT(varchar(64), HASHBYTES('SHA2_256', filas), 2) AS sha256
FROM (VALUES
    (N'DimFecha', (SELECT * FROM dw.DimFecha ORDER BY fecha_key FOR JSON PATH, INCLUDE_NULL_VALUES)),
    (N'DimCliente', (SELECT * FROM dw.DimCliente ORDER BY cliente_key FOR JSON PATH, INCLUDE_NULL_VALUES)),
    (N'DimProducto', (SELECT * FROM dw.DimProducto ORDER BY producto_key FOR JSON PATH, INCLUDE_NULL_VALUES)),
    (N'DimVendedor', (SELECT * FROM dw.DimVendedor ORDER BY vendedor_key FOR JSON PATH, INCLUDE_NULL_VALUES)),
    (N'DimGeografiaCliente', (SELECT * FROM dw.DimGeografiaCliente ORDER BY geografia_cliente_key FOR JSON PATH, INCLUDE_NULL_VALUES)),
    (N'DimGeografiaVendedor', (SELECT * FROM dw.DimGeografiaVendedor ORDER BY geografia_vendedor_key FOR JSON PATH, INCLUDE_NULL_VALUES)),
    (N'FactPedidos', (SELECT * FROM dw.FactPedidos ORDER BY pedido_key FOR JSON PATH, INCLUDE_NULL_VALUES)),
    (N'FactDetallePedido', (SELECT * FROM dw.FactDetallePedido ORDER BY pedido_detalle_key FOR JSON PATH, INCLUDE_NULL_VALUES))
) AS datos(tabla, filas)
ORDER BY tabla;
