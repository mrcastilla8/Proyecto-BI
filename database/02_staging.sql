USE BI_OLIST;
GO
/* Staging conserva filas repetidas: row_id técnico permite trazar duplicados legítimos/conflictivos. */
IF OBJECT_ID(N'stg.Orders',N'U') IS NULL CREATE TABLE stg.Orders(
 row_id BIGINT IDENTITY PRIMARY KEY, batch_id BIGINT NOT NULL REFERENCES audit.Batch(batch_id), source_row_number BIGINT NOT NULL,
 order_id VARCHAR(64) NULL, customer_id VARCHAR(64) NULL, order_status VARCHAR(32) NULL,
 order_purchase_timestamp DATETIME2(0) NULL, order_approved_at DATETIME2(0) NULL,
 order_delivered_carrier_date DATETIME2(0) NULL, order_delivered_customer_date DATETIME2(0) NULL, order_estimated_delivery_date DATETIME2(0) NULL,
 loaded_at DATETIME2(0) NOT NULL CONSTRAINT DF_stg_Orders_loaded DEFAULT(SYSDATETIME()));
IF OBJECT_ID(N'stg.OrderItems',N'U') IS NULL CREATE TABLE stg.OrderItems(
 row_id BIGINT IDENTITY PRIMARY KEY, batch_id BIGINT NOT NULL REFERENCES audit.Batch(batch_id), source_row_number BIGINT NOT NULL,
 order_id VARCHAR(64) NULL, order_item_id INT NULL, product_id VARCHAR(64) NULL, seller_id VARCHAR(64) NULL,
 shipping_limit_date DATETIME2(0) NULL, price DECIMAL(19,4) NULL, freight_value DECIMAL(19,4) NULL,
 loaded_at DATETIME2(0) NOT NULL CONSTRAINT DF_stg_OrderItems_loaded DEFAULT(SYSDATETIME()));
IF OBJECT_ID(N'stg.OrderPayments',N'U') IS NULL CREATE TABLE stg.OrderPayments(
 row_id BIGINT IDENTITY PRIMARY KEY, batch_id BIGINT NOT NULL REFERENCES audit.Batch(batch_id), source_row_number BIGINT NOT NULL,
 order_id VARCHAR(64) NULL, payment_sequential INT NULL, payment_type VARCHAR(32) NULL, payment_installments INT NULL, payment_value DECIMAL(19,4) NULL,
 loaded_at DATETIME2(0) NOT NULL CONSTRAINT DF_stg_OrderPayments_loaded DEFAULT(SYSDATETIME()));
IF OBJECT_ID(N'stg.OrderReviews',N'U') IS NULL CREATE TABLE stg.OrderReviews(
 row_id BIGINT IDENTITY PRIMARY KEY, batch_id BIGINT NOT NULL REFERENCES audit.Batch(batch_id), source_row_number BIGINT NOT NULL,
 review_id VARCHAR(64) NULL, order_id VARCHAR(64) NULL, review_score TINYINT NULL,
 review_comment_title NVARCHAR(1000) NULL, review_comment_message NVARCHAR(4000) NULL,
 review_creation_date DATETIME2(0) NULL, review_answer_timestamp DATETIME2(0) NULL,
 loaded_at DATETIME2(0) NOT NULL CONSTRAINT DF_stg_OrderReviews_loaded DEFAULT(SYSDATETIME()));
IF OBJECT_ID(N'stg.Customers',N'U') IS NULL CREATE TABLE stg.Customers(
 row_id BIGINT IDENTITY PRIMARY KEY, batch_id BIGINT NOT NULL REFERENCES audit.Batch(batch_id), source_row_number BIGINT NOT NULL,
 customer_id VARCHAR(64) NULL, customer_unique_id VARCHAR(64) NULL, customer_zip_code_prefix CHAR(5) NULL,
 customer_city NVARCHAR(200) NULL, customer_state CHAR(2) NULL, loaded_at DATETIME2(0) NOT NULL CONSTRAINT DF_stg_Customers_loaded DEFAULT(SYSDATETIME()));
IF OBJECT_ID(N'stg.Sellers',N'U') IS NULL CREATE TABLE stg.Sellers(
 row_id BIGINT IDENTITY PRIMARY KEY, batch_id BIGINT NOT NULL REFERENCES audit.Batch(batch_id), source_row_number BIGINT NOT NULL,
 seller_id VARCHAR(64) NULL, seller_zip_code_prefix CHAR(5) NULL, seller_city NVARCHAR(200) NULL, seller_state CHAR(2) NULL,
 loaded_at DATETIME2(0) NOT NULL CONSTRAINT DF_stg_Sellers_loaded DEFAULT(SYSDATETIME()));
IF OBJECT_ID(N'stg.Products',N'U') IS NULL CREATE TABLE stg.Products(
 row_id BIGINT IDENTITY PRIMARY KEY, batch_id BIGINT NOT NULL REFERENCES audit.Batch(batch_id), source_row_number BIGINT NOT NULL,
 product_id VARCHAR(64) NULL, product_category_name NVARCHAR(200) NULL, product_name_lenght INT NULL,
 product_description_lenght INT NULL, product_photos_qty INT NULL, product_weight_g DECIMAL(12,3) NULL,
 product_length_cm DECIMAL(12,3) NULL, product_height_cm DECIMAL(12,3) NULL, product_width_cm DECIMAL(12,3) NULL,
 loaded_at DATETIME2(0) NOT NULL CONSTRAINT DF_stg_Products_loaded DEFAULT(SYSDATETIME()));
IF OBJECT_ID(N'stg.Geolocation',N'U') IS NULL CREATE TABLE stg.Geolocation(
 row_id BIGINT IDENTITY PRIMARY KEY, batch_id BIGINT NOT NULL REFERENCES audit.Batch(batch_id), source_row_number BIGINT NOT NULL,
 geolocation_zip_code_prefix CHAR(5) NULL, geolocation_lat DECIMAL(24,20) NULL, geolocation_lng DECIMAL(24,16) NULL,
 geolocation_city NVARCHAR(200) NULL, geolocation_state CHAR(2) NULL, loaded_at DATETIME2(0) NOT NULL CONSTRAINT DF_stg_Geolocation_loaded DEFAULT(SYSDATETIME()));
IF OBJECT_ID(N'stg.ProductCategoryTranslation',N'U') IS NULL CREATE TABLE stg.ProductCategoryTranslation(
 row_id BIGINT IDENTITY PRIMARY KEY, batch_id BIGINT NOT NULL REFERENCES audit.Batch(batch_id), source_row_number BIGINT NOT NULL,
 product_category_name NVARCHAR(200) NULL, product_category_name_english NVARCHAR(200) NULL,
 loaded_at DATETIME2(0) NOT NULL CONSTRAINT DF_stg_Category_loaded DEFAULT(SYSDATETIME()));
GO
/* Unicidad técnica por origen dentro del lote; las claves de negocio no se restringen. */
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
