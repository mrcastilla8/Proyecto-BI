USE BI_OLIST;
GO
IF OBJECT_ID(N'dw.FactPedidos',N'U') IS NULL CREATE TABLE dw.FactPedidos(
 pedido_key BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactPedidos PRIMARY KEY,
 order_id VARCHAR(64) NOT NULL, cliente_key INT NOT NULL, geografia_cliente_key INT NOT NULL,
 fecha_compra_key INT NOT NULL, fecha_entrega_estimada_key INT NOT NULL, fecha_entrega_real_key INT NOT NULL,
 order_status VARCHAR(32) NOT NULL, order_purchase_timestamp DATETIME2(0) NULL,
 order_estimated_delivery_date DATETIME2(0) NULL, order_delivered_customer_date DATETIME2(0) NULL,
 payment_value_total DECIMAL(19,4) NULL, review_score DECIMAL(9,4) NULL,
 CONSTRAINT UQ_FactPedidos_order UNIQUE(order_id),
 CONSTRAINT FK_FactPedidos_Cliente FOREIGN KEY(cliente_key) REFERENCES dw.DimCliente(cliente_key),
 CONSTRAINT FK_FactPedidos_GeoCliente FOREIGN KEY(geografia_cliente_key) REFERENCES dw.DimGeografiaCliente(geografia_cliente_key),
 CONSTRAINT FK_FactPedidos_FechaCompra FOREIGN KEY(fecha_compra_key) REFERENCES dw.DimFecha(fecha_key),
 CONSTRAINT FK_FactPedidos_FechaEstimada FOREIGN KEY(fecha_entrega_estimada_key) REFERENCES dw.DimFecha(fecha_key),
 CONSTRAINT FK_FactPedidos_FechaReal FOREIGN KEY(fecha_entrega_real_key) REFERENCES dw.DimFecha(fecha_key),
 CONSTRAINT CK_FactPedidos_score CHECK(review_score IS NULL OR review_score BETWEEN 1 AND 5));
IF OBJECT_ID(N'dw.FactDetallePedido',N'U') IS NULL CREATE TABLE dw.FactDetallePedido(
 pedido_detalle_key BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactDetallePedido PRIMARY KEY,
 order_id VARCHAR(64) NOT NULL, order_item_id INT NOT NULL,
 producto_key INT NOT NULL, vendedor_key INT NOT NULL, cliente_key INT NOT NULL,
 geografia_cliente_key INT NOT NULL, geografia_vendedor_key INT NOT NULL, fecha_compra_key INT NOT NULL,
 order_status VARCHAR(32) NOT NULL, price DECIMAL(19,4) NOT NULL, freight_value DECIMAL(19,4) NOT NULL,
 CONSTRAINT UQ_FactDetallePedido_grain UNIQUE(order_id,order_item_id),
 CONSTRAINT CK_FactDetallePedido_item CHECK(order_item_id>0),
 CONSTRAINT FK_FactDetalle_Producto FOREIGN KEY(producto_key) REFERENCES dw.DimProducto(producto_key),
 CONSTRAINT FK_FactDetalle_Vendedor FOREIGN KEY(vendedor_key) REFERENCES dw.DimVendedor(vendedor_key),
 CONSTRAINT FK_FactDetalle_Cliente FOREIGN KEY(cliente_key) REFERENCES dw.DimCliente(cliente_key),
 CONSTRAINT FK_FactDetalle_GeoCliente FOREIGN KEY(geografia_cliente_key) REFERENCES dw.DimGeografiaCliente(geografia_cliente_key),
 CONSTRAINT FK_FactDetalle_GeoVendedor FOREIGN KEY(geografia_vendedor_key) REFERENCES dw.DimGeografiaVendedor(geografia_vendedor_key),
 CONSTRAINT FK_FactDetalle_FechaCompra FOREIGN KEY(fecha_compra_key) REFERENCES dw.DimFecha(fecha_key));
GO
