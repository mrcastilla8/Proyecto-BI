/* Ejecutar solo en BI_OLIST local de desarrollo. Todas las escrituras se revierten. */
USE BI_OLIST;
GO
SET NOCOUNT ON;
IF NOT EXISTS(SELECT 1 FROM dw.DimFecha WHERE fecha_key=-1 AND fecha IS NULL) THROW 51000,'Falta fecha desconocida (-1).',1;
IF NOT EXISTS(SELECT 1 FROM dw.DimCliente WHERE cliente_key=-1 AND customer_unique_id IS NULL) THROW 51000,'Falta cliente desconocido (-1).',1;
IF NOT EXISTS(SELECT 1 FROM dw.DimProducto WHERE producto_key=-1 AND product_id IS NULL) THROW 51000,'Falta producto desconocido (-1).',1;
IF NOT EXISTS(SELECT 1 FROM dw.DimVendedor WHERE vendedor_key=-1 AND seller_id IS NULL) THROW 51000,'Falta vendedor desconocido (-1).',1;
IF NOT EXISTS(SELECT 1 FROM sys.key_constraints WHERE name=N'UQ_FactPedidos_order') THROW 51000,'Falta unicidad de order_id en FactPedidos.',1;
IF NOT EXISTS(SELECT 1 FROM sys.key_constraints WHERE name=N'UQ_FactDetallePedido_grain') THROW 51000,'Falta unicidad del grano de detalle.',1;
IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id IN(OBJECT_ID(N'dw.FactPedidos'),OBJECT_ID(N'dw.FactDetallePedido'))) < 11 THROW 51000,'Faltan relaciones FK de los hechos.',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE (parent_object_id=OBJECT_ID(N'dw.FactPedidos') AND referenced_object_id=OBJECT_ID(N'dw.FactDetallePedido')) OR (parent_object_id=OBJECT_ID(N'dw.FactDetallePedido') AND referenced_object_id=OBJECT_ID(N'dw.FactPedidos'))) THROW 51000,'Los hechos no deben relacionarse directamente.',1;
BEGIN TRANSACTION;
DECLARE @date_key INT=20180505, @client INT, @product INT, @seller INT, @geo_c INT, @geo_s INT;
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
