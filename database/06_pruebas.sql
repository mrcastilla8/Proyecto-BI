/* Ejecutar solo en BI_OLIST local de desarrollo. Todas las escrituras se revierten. */
USE BI_OLIST;
GO
SET NOCOUNT ON;
SET XACT_ABORT OFF;
IF NOT EXISTS(SELECT 1 FROM dw.DimFecha WHERE fecha_key=-1 AND fecha IS NULL) THROW 51000,'Falta fecha desconocida (-1).',1;
IF NOT EXISTS(SELECT 1 FROM dw.DimCliente WHERE cliente_key=-1 AND customer_unique_id IS NULL) THROW 51000,'Falta cliente desconocido (-1).',1;
IF NOT EXISTS(SELECT 1 FROM dw.DimProducto WHERE producto_key=-1 AND product_id IS NULL) THROW 51000,'Falta producto desconocido (-1).',1;
IF NOT EXISTS(SELECT 1 FROM dw.DimVendedor WHERE vendedor_key=-1 AND seller_id IS NULL) THROW 51000,'Falta vendedor desconocido (-1).',1;
IF NOT EXISTS(SELECT 1 FROM sys.key_constraints WHERE name=N'UQ_FactPedidos_order') THROW 51000,'Falta unicidad de order_id en FactPedidos.',1;
IF NOT EXISTS(SELECT 1 FROM sys.key_constraints WHERE name=N'UQ_FactDetallePedido_grain') THROW 51000,'Falta unicidad del grano de detalle.',1;
IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id IN(OBJECT_ID(N'dw.FactPedidos'),OBJECT_ID(N'dw.FactDetallePedido'))) < 11 THROW 51000,'Faltan relaciones FK de los hechos.',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE (parent_object_id=OBJECT_ID(N'dw.FactPedidos') AND referenced_object_id=OBJECT_ID(N'dw.FactDetallePedido')) OR (parent_object_id=OBJECT_ID(N'dw.FactDetallePedido') AND referenced_object_id=OBJECT_ID(N'dw.FactPedidos'))) THROW 51000,'Los hechos no deben relacionarse directamente.',1;
DECLARE @stage_names TABLE(table_name SYSNAME, probe_column SYSNAME);
INSERT @stage_names VALUES
 (N'Orders',N'order_id'),(N'OrderItems',N'order_id'),(N'OrderPayments',N'order_id'),
 (N'OrderReviews',N'review_id'),(N'Customers',N'customer_id'),(N'Sellers',N'seller_id'),
 (N'Products',N'product_id'),(N'Geolocation',N'geolocation_zip_code_prefix'),
 (N'ProductCategoryTranslation',N'product_category_name');
IF EXISTS(SELECT 1 FROM @stage_names s LEFT JOIN sys.indexes i ON i.object_id=OBJECT_ID(N'stg.'+s.table_name) AND i.name=N'UX_'+s.table_name+N'_batch_source_row' AND i.is_unique=1 WHERE i.index_id IS NULL)
 THROW 51003,'Falta índice único batch_id/source_row_number en una tabla staging.',1;
DECLARE @negative_batch BIGINT, @negative_error INT;
/* Negativos de CHECK/trigger se aíslan en transacciones que se revierten completas. */
BEGIN TRANSACTION;
INSERT audit.Batch(source_name,contract_version,status) VALUES(N'TEST-INVALID-COUNTS','1.0.0','PENDING');
SET @negative_batch=SCOPE_IDENTITY();
BEGIN TRY
 UPDATE audit.Batch SET rows_read=1,rows_accepted=1,rows_rejected=1 WHERE batch_id=@negative_batch;
 THROW 51011,'Se aceptó rows_read menor que las filas clasificadas.',1;
END TRY
BEGIN CATCH
 SET @negative_error=ERROR_NUMBER();
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 IF @negative_error<>547 THROW;
END CATCH;
BEGIN TRANSACTION;
INSERT audit.Batch(source_name,contract_version,status) VALUES(N'TEST-PARTIAL-COMPLETE','1.0.0','PENDING');
SET @negative_batch=SCOPE_IDENTITY();
UPDATE audit.Batch SET rows_read=10,rows_accepted=3,rows_rejected=2,status='RUNNING' WHERE batch_id=@negative_batch;
BEGIN TRY
 UPDATE audit.Batch SET status='COMPLETE',finished_at=SYSDATETIME() WHERE batch_id=@negative_batch;
 THROW 51004,'Se aceptaron contadores parciales en COMPLETE.',1;
END TRY
BEGIN CATCH
 SET @negative_error=ERROR_NUMBER();
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 IF @negative_error<>547 THROW;
END CATCH;
BEGIN TRANSACTION;
INSERT audit.Batch(source_name,contract_version,status) VALUES(N'TEST-INVALID-TRANSITION','1.0.0','PENDING');
SET @negative_batch=SCOPE_IDENTITY();
BEGIN TRY
 UPDATE audit.Batch SET status='COMPLETE',finished_at=SYSDATETIME() WHERE batch_id=@negative_batch;
 THROW 51007,'Se aceptó transición PENDING a COMPLETE.',1;
END TRY
BEGIN CATCH
 SET @negative_error=ERROR_NUMBER();
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 IF @negative_error<>51030 THROW;
END CATCH;
BEGIN TRANSACTION;
DECLARE @date_key INT=20180505, @client INT, @product INT, @seller INT, @geo_c INT, @geo_s INT,
        @pending_batch BIGINT, @running_batch BIGINT, @stage_batch BIGINT,
        @table SYSNAME, @probe SYSNAME, @sql NVARCHAR(MAX);
/* Estados inicial, parcial, finalización y reinicio tras fallo. */
INSERT audit.Batch(source_name,contract_version,status) VALUES(N'TEST-PENDING','1.0.0','PENDING');
SET @pending_batch=SCOPE_IDENTITY();
UPDATE audit.Batch SET rows_read=10,rows_accepted=3,rows_rejected=2 WHERE batch_id=@pending_batch;
UPDATE audit.Batch SET status='RUNNING' WHERE batch_id=@pending_batch;
UPDATE audit.Batch SET rows_read=10,rows_accepted=7,rows_rejected=3,status='COMPLETE',finished_at=SYSDATETIME() WHERE batch_id=@pending_batch;
IF NOT EXISTS(SELECT 1 FROM audit.Batch WHERE batch_id=@pending_batch AND status='COMPLETE' AND rows_read=rows_accepted+rows_rejected AND finished_at IS NOT NULL)
 THROW 51005,'No se completó lote con contadores conciliados.',1;
INSERT audit.Batch(source_name,contract_version,status) VALUES(N'TEST-FAILED','1.0.0','PENDING');
SET @running_batch=SCOPE_IDENTITY();
UPDATE audit.Batch SET status='RUNNING',started_at=DATEADD(SECOND,1,started_at),rows_read=6,rows_accepted=2,rows_rejected=1 WHERE batch_id=@running_batch;
UPDATE audit.Batch SET status='FAILED',finished_at=DATEADD(SECOND,1,started_at),error_message=N'fallo sintético' WHERE batch_id=@running_batch;
UPDATE audit.Batch SET status='RUNNING',started_at=DATEADD(SECOND,1,started_at),finished_at=NULL,error_message=NULL,rows_read=0,rows_accepted=0,rows_rejected=0 WHERE batch_id=@running_batch;
IF NOT EXISTS(SELECT 1 FROM audit.Batch WHERE batch_id=@running_batch AND status='RUNNING' AND finished_at IS NULL AND rows_read=0)
 THROW 51006,'No se pudo reiniciar un lote fallido.',1;
/* Dos filas fuente idénticas con distinto ordinal se conservan; ordinal repetido se rechaza. */
INSERT audit.Batch(source_name,contract_version,status) VALUES(N'TEST-STAGING','1.0.0','RUNNING');
SET @stage_batch=SCOPE_IDENTITY();
DECLARE stage_test CURSOR LOCAL FAST_FORWARD FOR SELECT table_name,probe_column FROM @stage_names;
OPEN stage_test;
FETCH NEXT FROM stage_test INTO @table,@probe;
WHILE @@FETCH_STATUS=0
BEGIN
 SET @sql=N'INSERT stg.'+QUOTENAME(@table)+N'(batch_id,source_row_number,'+QUOTENAME(@probe)+N') VALUES(@b,101,N''DUP01''),(@b,102,N''DUP01''); IF (SELECT COUNT_BIG(*) FROM stg.'+QUOTENAME(@table)+N' WHERE batch_id=@b AND '+QUOTENAME(@probe)+N'=N''DUP01'')<>2 THROW 51008,''No se conservaron las dos filas fuente duplicadas.'',1;';
 EXEC sys.sp_executesql @sql,N'@b BIGINT',@b=@stage_batch;
 SET @sql=N'INSERT stg.'+QUOTENAME(@table)+N'(batch_id,source_row_number,'+QUOTENAME(@probe)+N') VALUES(@b,101,N''DUP01'');';
 SAVE TRANSACTION before_duplicate_stage_row;
 BEGIN TRY
  EXEC sys.sp_executesql @sql,N'@b BIGINT',@b=@stage_batch;
  THROW 51009,'Se aceptó el mismo lote/fila más de una vez.',1;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()=1 ROLLBACK TRANSACTION before_duplicate_stage_row;
  IF ERROR_NUMBER() NOT IN (2601,2627) THROW;
 END CATCH;
 FETCH NEXT FROM stage_test INTO @table,@probe;
END;
CLOSE stage_test;
DEALLOCATE stage_test;
IF NOT EXISTS(SELECT 1 FROM dw.DimFecha WHERE fecha_key=@date_key) INSERT dw.DimFecha(fecha_key,fecha,anio,trimestre,mes,nombre_mes,dia,dia_semana) VALUES(@date_key,'2018-05-05',2018,2,5,N'mayo',5,7);
IF NOT EXISTS(SELECT 1 FROM dw.DimCliente WHERE customer_unique_id='TEST-CLIENT') INSERT dw.DimCliente(customer_unique_id) VALUES('TEST-CLIENT');
IF NOT EXISTS(SELECT 1 FROM dw.DimProducto WHERE product_id='TEST-PRODUCT') INSERT dw.DimProducto(product_id) VALUES('TEST-PRODUCT');
IF NOT EXISTS(SELECT 1 FROM dw.DimVendedor WHERE seller_id='TEST-SELLER') INSERT dw.DimVendedor(seller_id) VALUES('TEST-SELLER');
IF NOT EXISTS(SELECT 1 FROM dw.DimGeografiaCliente WHERE customer_state='ZZ' AND customer_city=N'Test') INSERT dw.DimGeografiaCliente(customer_state,customer_city) VALUES('ZZ',N'Test');
IF NOT EXISTS(SELECT 1 FROM dw.DimGeografiaVendedor WHERE seller_state='ZZ' AND seller_city=N'Test') INSERT dw.DimGeografiaVendedor(seller_state,seller_city) VALUES('ZZ',N'Test');
SELECT @client=cliente_key FROM dw.DimCliente WHERE customer_unique_id='TEST-CLIENT';
SELECT @product=producto_key FROM dw.DimProducto WHERE product_id='TEST-PRODUCT';
SELECT @seller=vendedor_key FROM dw.DimVendedor WHERE seller_id='TEST-SELLER';
SELECT @geo_c=geografia_cliente_key FROM dw.DimGeografiaCliente WHERE customer_state='ZZ' AND customer_city=N'Test';
SELECT @geo_s=geografia_vendedor_key FROM dw.DimGeografiaVendedor WHERE seller_state='ZZ' AND seller_city=N'Test';
INSERT dw.FactPedidos(order_id,cliente_key,geografia_cliente_key,fecha_compra_key,fecha_entrega_estimada_key,fecha_entrega_real_key,order_status,order_purchase_timestamp,order_estimated_delivery_date,order_delivered_customer_date,payment_value_total,review_score)
 VALUES('TEST-ORDER-EMPTY',@client,@geo_c,@date_key,-1,-1,'created','2018-05-05T10:00:00',NULL,NULL,NULL,NULL),
       ('TEST-ORDER-MULTI',@client,@geo_c,@date_key,@date_key,@date_key,'delivered','2018-05-05T10:00:00','2018-05-05T00:00:00','2018-05-05T22:00:00',30.0000,4.5000);
INSERT dw.FactDetallePedido(order_id,order_item_id,producto_key,vendedor_key,cliente_key,geografia_cliente_key,geografia_vendedor_key,fecha_compra_key,order_status,price,freight_value)
 VALUES('TEST-ORDER-MULTI',1,@product,@seller,@client,@geo_c,@geo_s,@date_key,'delivered',10.0000,2.0000),
       ('TEST-ORDER-MULTI',2,@product,@seller,@client,@geo_c,@geo_s,@date_key,'delivered',20.0000,3.0000);
IF (SELECT COUNT(*) FROM dw.FactPedidos WHERE order_id LIKE 'TEST-ORDER-%')<>2 THROW 51000,'Pedido sin línea o hecho de pedido incorrecto.',1;
IF (SELECT COUNT(*) FROM dw.FactDetallePedido WHERE order_id='TEST-ORDER-MULTI')<>2 THROW 51000,'Grano de detalle incorrecto.',1;
IF (SELECT SUM(price) FROM dw.FactDetallePedido WHERE order_id='TEST-ORDER-MULTI')<>30.0000 THROW 51000,'Suma de importes de líneas incorrecta.',1;
IF (SELECT SUM(freight_value) FROM dw.FactDetallePedido WHERE order_id='TEST-ORDER-MULTI')<>5.0000 THROW 51000,'Suma de flete incorrecta.',1;
IF CAST('2018-05-05T22:00:00' AS DATE)>CAST('2018-05-05T00:00:00' AS DATE) THROW 51000,'Comparación inclusiva por día incorrecta.',1;
IF CAST('2018-05-06T00:00:00' AS DATE)<=CAST('2018-05-05T23:59:00' AS DATE) THROW 51000,'No detectó entrega del día siguiente.',1;
/* La segunda reseña no puede alterar el total del hecho al cruzar relaciones: agregación por pedido. */
IF (SELECT AVG(review_score) FROM dw.FactPedidos WHERE order_id='TEST-ORDER-MULTI')<>4.5000 THROW 51000,'Calificación por pedido incorrecta.',1;
SAVE TRANSACTION before_duplicate_order;
BEGIN TRY
 INSERT dw.FactPedidos(order_id,cliente_key,geografia_cliente_key,fecha_compra_key,fecha_entrega_estimada_key,fecha_entrega_real_key,order_status)
 SELECT order_id,cliente_key,geografia_cliente_key,fecha_compra_key,fecha_entrega_estimada_key,fecha_entrega_real_key,order_status
 FROM dw.FactPedidos WHERE order_id='TEST-ORDER-EMPTY';
 THROW 51001,'Se aceptó un order_id duplicado.',1;
END TRY
BEGIN CATCH
 IF XACT_STATE()=1 ROLLBACK TRANSACTION before_duplicate_order;
 IF ERROR_NUMBER() NOT IN (2601,2627) THROW;
END CATCH;
SAVE TRANSACTION before_orphan_fk;
BEGIN TRY
 INSERT dw.FactDetallePedido(order_id,order_item_id,producto_key,vendedor_key,cliente_key,geografia_cliente_key,geografia_vendedor_key,fecha_compra_key,order_status,price,freight_value)
 VALUES('TEST-ORPHAN',1,-999,-999,-999,-999,-999,@date_key,'invalid',1.0000,0.0000);
 THROW 51002,'Se aceptaron claves foráneas huérfanas.',1;
END TRY
BEGIN CATCH
 IF XACT_STATE()=1 ROLLBACK TRANSACTION before_orphan_fk;
 IF ERROR_NUMBER()<>547 THROW;
END CATCH;
ROLLBACK TRANSACTION;
PRINT 'PASS: casos positivos/negativos, integridad, granos, pedido sin líneas, importes y fechas; cambios revertidos.';
GO
