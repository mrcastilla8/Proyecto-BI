USE BI_OLIST;
GO
/* Migración aditiva: aplica unicidad técnica también si las tablas stg ya existían. */
DECLARE @staging_name SYSNAME, @staging_sql NVARCHAR(MAX);
DECLARE staging_tables CURSOR LOCAL FAST_FORWARD FOR
 SELECT name FROM (VALUES(N'Orders'),(N'OrderItems'),(N'OrderPayments'),(N'OrderReviews'),(N'Customers'),(N'Sellers'),(N'Products'),(N'Geolocation'),(N'ProductCategoryTranslation')) AS t(name);
OPEN staging_tables;
FETCH NEXT FROM staging_tables INTO @staging_name;
WHILE @@FETCH_STATUS=0
BEGIN
 SET @staging_sql=N'IF EXISTS(SELECT 1 FROM stg.'+QUOTENAME(@staging_name)+N' GROUP BY batch_id,source_row_number HAVING COUNT_BIG(*)>1) THROW 51020, ''Duplicate batch/source row in staging.'',1; IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N''stg.'+@staging_name+N''') AND name=N''UX_'+@staging_name+N'_batch_source_row'') CREATE UNIQUE INDEX '+QUOTENAME(N'UX_'+@staging_name+N'_batch_source_row')+N' ON stg.'+QUOTENAME(@staging_name)+N'(batch_id,source_row_number);';
 EXEC sys.sp_executesql @staging_sql;
 FETCH NEXT FROM staging_tables INTO @staging_name;
END;
CLOSE staging_tables;
DEALLOCATE staging_tables;
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dw.FactDetallePedido') AND name=N'IX_FactDetallePedido_Fecha')
 CREATE INDEX IX_FactDetallePedido_Fecha ON dw.FactDetallePedido(fecha_compra_key) INCLUDE(order_status,price,freight_value);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dw.FactDetallePedido') AND name=N'IX_FactDetallePedido_Producto')
 CREATE INDEX IX_FactDetallePedido_Producto ON dw.FactDetallePedido(producto_key,fecha_compra_key);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dw.FactDetallePedido') AND name=N'IX_FactDetallePedido_Vendedor')
 CREATE INDEX IX_FactDetallePedido_Vendedor ON dw.FactDetallePedido(vendedor_key,fecha_compra_key);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dw.FactPedidos') AND name=N'IX_FactPedidos_FechaCompra')
 CREATE INDEX IX_FactPedidos_FechaCompra ON dw.FactPedidos(fecha_compra_key) INCLUDE(order_status,payment_value_total,review_score);
GO
CREATE OR ALTER VIEW audit.vw_BatchStatus AS
 SELECT b.batch_id,b.source_name,b.source_file,b.status,b.started_at,b.finished_at,b.rows_read,b.rows_accepted,b.rows_rejected,
        COUNT_BIG(r.reject_id) AS rejection_records,b.error_message
 FROM audit.Batch b LEFT JOIN audit.Reject r ON r.batch_id=b.batch_id
 GROUP BY b.batch_id,b.source_name,b.source_file,b.status,b.started_at,b.finished_at,b.rows_read,b.rows_accepted,b.rows_rejected,b.error_message;
GO
/* Diagnóstico de duplicados por lote; staging deliberadamente no los bloquea. */
SELECT batch_id,order_id,COUNT_BIG(*) AS row_count FROM stg.Orders WHERE order_id IS NOT NULL GROUP BY batch_id,order_id HAVING COUNT_BIG(*)>1;
SELECT batch_id,order_id,order_item_id,COUNT_BIG(*) AS row_count FROM stg.OrderItems WHERE order_id IS NOT NULL AND order_item_id IS NOT NULL GROUP BY batch_id,order_id,order_item_id HAVING COUNT_BIG(*)>1;
SELECT batch_id,order_id,payment_sequential,COUNT_BIG(*) AS row_count FROM stg.OrderPayments WHERE order_id IS NOT NULL AND payment_sequential IS NOT NULL GROUP BY batch_id,order_id,payment_sequential HAVING COUNT_BIG(*)>1;
SELECT batch_id,review_id,COUNT_BIG(*) AS row_count FROM stg.OrderReviews WHERE review_id IS NOT NULL GROUP BY batch_id,review_id HAVING COUNT_BIG(*)>1;
/* Conciliaciones de salida. */
SELECT (SELECT COUNT_BIG(*) FROM dw.FactPedidos) AS pedidos,
       (SELECT COUNT_BIG(DISTINCT order_id) FROM dw.FactPedidos) AS pedidos_distintos,
       (SELECT COUNT_BIG(*) FROM dw.FactDetallePedido) AS lineas,
       (SELECT COUNT_BIG(*) FROM dw.FactDetallePedido d WHERE NOT EXISTS(SELECT 1 FROM dw.FactPedidos p WHERE p.order_id=d.order_id)) AS lineas_sin_pedido;
SELECT order_id,COUNT_BIG(*) AS filas FROM dw.FactPedidos GROUP BY order_id HAVING COUNT_BIG(*)<>1;
SELECT order_id,order_item_id,COUNT_BIG(*) AS filas FROM dw.FactDetallePedido GROUP BY order_id,order_item_id HAVING COUNT_BIG(*)<>1;
GO
