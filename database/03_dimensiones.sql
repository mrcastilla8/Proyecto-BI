USE BI_OLIST;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID(N'dw.DimFecha',N'U') IS NULL CREATE TABLE dw.DimFecha(
 fecha_key INT NOT NULL CONSTRAINT PK_DimFecha PRIMARY KEY,
 fecha DATE NULL, anio SMALLINT NULL, trimestre TINYINT NULL, mes TINYINT NULL,
 nombre_mes NVARCHAR(20) NULL, dia TINYINT NULL, dia_semana TINYINT NULL,
 CONSTRAINT CK_DimFecha_key CHECK(fecha_key=-1 OR (fecha IS NOT NULL AND fecha_key=CONVERT(INT,CONVERT(CHAR(8),fecha,112)))),
 CONSTRAINT CK_DimFecha_unknown CHECK((fecha_key=-1 AND fecha IS NULL) OR (fecha_key<>-1 AND fecha IS NOT NULL)));
IF OBJECT_ID(N'dw.DimCliente',N'U') IS NULL CREATE TABLE dw.DimCliente(
 cliente_key INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCliente PRIMARY KEY,
 customer_unique_id VARCHAR(64) NULL, CONSTRAINT UQ_DimCliente_business UNIQUE(customer_unique_id),
 CONSTRAINT CK_DimCliente_unknown CHECK(cliente_key<>-1 OR customer_unique_id IS NULL));
IF OBJECT_ID(N'dw.DimProducto',N'U') IS NULL CREATE TABLE dw.DimProducto(
 producto_key INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimProducto PRIMARY KEY,
 product_id VARCHAR(64) NULL, product_category_name NVARCHAR(200) NULL, product_category_name_english NVARCHAR(200) NULL,
 product_name_lenght INT NULL, product_description_lenght INT NULL, product_photos_qty INT NULL,
 product_weight_g DECIMAL(12,3) NULL, product_length_cm DECIMAL(12,3) NULL, product_height_cm DECIMAL(12,3) NULL, product_width_cm DECIMAL(12,3) NULL,
 CONSTRAINT UQ_DimProducto_business UNIQUE(product_id), CONSTRAINT CK_DimProducto_unknown CHECK(producto_key<>-1 OR product_id IS NULL));
IF OBJECT_ID(N'dw.DimVendedor',N'U') IS NULL CREATE TABLE dw.DimVendedor(
 vendedor_key INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimVendedor PRIMARY KEY,
 seller_id VARCHAR(64) NULL, CONSTRAINT UQ_DimVendedor_business UNIQUE(seller_id),
 CONSTRAINT CK_DimVendedor_unknown CHECK(vendedor_key<>-1 OR seller_id IS NULL));
IF OBJECT_ID(N'dw.DimGeografiaCliente',N'U') IS NULL CREATE TABLE dw.DimGeografiaCliente(
 geografia_cliente_key INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimGeografiaCliente PRIMARY KEY,
 customer_city NVARCHAR(200) NULL, customer_state CHAR(2) NULL,
 CONSTRAINT UQ_DimGeoCliente_business UNIQUE(customer_state,customer_city),
 CONSTRAINT CK_DimGeoCliente_unknown CHECK(geografia_cliente_key<>-1 OR (customer_city IS NULL AND customer_state IS NULL)));
IF OBJECT_ID(N'dw.DimGeografiaVendedor',N'U') IS NULL CREATE TABLE dw.DimGeografiaVendedor(
 geografia_vendedor_key INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimGeografiaVendedor PRIMARY KEY,
 seller_city NVARCHAR(200) NULL, seller_state CHAR(2) NULL,
 CONSTRAINT UQ_DimGeoVendedor_business UNIQUE(seller_state,seller_city),
 CONSTRAINT CK_DimGeoVendedor_unknown CHECK(geografia_vendedor_key<>-1 OR (seller_city IS NULL AND seller_state IS NULL)));
IF NOT EXISTS(SELECT 1 FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID(N'dw.DimGeografiaCliente') AND name=N'UQ_DimGeoCliente_business')
 ALTER TABLE dw.DimGeografiaCliente ADD CONSTRAINT UQ_DimGeoCliente_business UNIQUE(customer_state,customer_city);
IF NOT EXISTS(SELECT 1 FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID(N'dw.DimGeografiaVendedor') AND name=N'UQ_DimGeoVendedor_business')
 ALTER TABLE dw.DimGeografiaVendedor ADD CONSTRAINT UQ_DimGeoVendedor_business UNIQUE(seller_state,seller_city);
GO
/* Miembros técnicos, cargados una sola vez y no asociados a fechas/entidades reales. */
IF NOT EXISTS(SELECT 1 FROM dw.DimFecha WHERE fecha_key=-1)
 INSERT dw.DimFecha(fecha_key,fecha) VALUES(-1,NULL);
SET IDENTITY_INSERT dw.DimCliente ON;
IF NOT EXISTS(SELECT 1 FROM dw.DimCliente WHERE cliente_key=-1) INSERT dw.DimCliente(cliente_key,customer_unique_id) VALUES(-1,NULL);
SET IDENTITY_INSERT dw.DimCliente OFF;
SET IDENTITY_INSERT dw.DimProducto ON;
IF NOT EXISTS(SELECT 1 FROM dw.DimProducto WHERE producto_key=-1) INSERT dw.DimProducto(producto_key,product_id) VALUES(-1,NULL);
SET IDENTITY_INSERT dw.DimProducto OFF;
SET IDENTITY_INSERT dw.DimVendedor ON;
IF NOT EXISTS(SELECT 1 FROM dw.DimVendedor WHERE vendedor_key=-1) INSERT dw.DimVendedor(vendedor_key,seller_id) VALUES(-1,NULL);
SET IDENTITY_INSERT dw.DimVendedor OFF;
SET IDENTITY_INSERT dw.DimGeografiaCliente ON;
IF NOT EXISTS(SELECT 1 FROM dw.DimGeografiaCliente WHERE geografia_cliente_key=-1) INSERT dw.DimGeografiaCliente(geografia_cliente_key) VALUES(-1);
SET IDENTITY_INSERT dw.DimGeografiaCliente OFF;
SET IDENTITY_INSERT dw.DimGeografiaVendedor ON;
IF NOT EXISTS(SELECT 1 FROM dw.DimGeografiaVendedor WHERE geografia_vendedor_key=-1) INSERT dw.DimGeografiaVendedor(geografia_vendedor_key) VALUES(-1);
SET IDENTITY_INSERT dw.DimGeografiaVendedor OFF;
GO
