-- Carga sintética exclusiva para una instancia LocalDB nueva dedicada al issue 2.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME()<>N'BI_OLIST' OR COALESCE(CONVERT(int, SERVERPROPERTY('IsLocalDB')), 0)<>1
   OR EXISTS (SELECT 1 FROM audit.Batch)
   OR EXISTS (SELECT 1 FROM dw.FactPedidos) OR EXISTS (SELECT 1 FROM dw.FactDetallePedido)
    THROW 52030, N'Las fixtures requieren una BI_OLIST vacía en una instancia LocalDB de pruebas.', 1;

BEGIN TRANSACTION;
DECLARE @Ids table(fuente sysname, lote bigint);
INSERT audit.Batch(source_name, status)
OUTPUT INSERTED.source_name, INSERTED.batch_id INTO @Ids
VALUES (N'Orders','RUNNING'), (N'OrderItems','RUNNING'), (N'OrderPayments','RUNNING'),
       (N'OrderReviews','RUNNING'), (N'Customers','RUNNING'), (N'Sellers','RUNNING'),
       (N'Products','RUNNING'), (N'Geolocation','RUNNING'), (N'ProductCategoryTranslation','RUNNING');

DECLARE @Orders bigint=(SELECT lote FROM @Ids WHERE fuente=N'Orders'),
        @Items bigint=(SELECT lote FROM @Ids WHERE fuente=N'OrderItems'),
        @Payments bigint=(SELECT lote FROM @Ids WHERE fuente=N'OrderPayments'),
        @Reviews bigint=(SELECT lote FROM @Ids WHERE fuente=N'OrderReviews'),
        @Customers bigint=(SELECT lote FROM @Ids WHERE fuente=N'Customers'),
        @Sellers bigint=(SELECT lote FROM @Ids WHERE fuente=N'Sellers'),
        @Products bigint=(SELECT lote FROM @Ids WHERE fuente=N'Products'),
        @Geo bigint=(SELECT lote FROM @Ids WHERE fuente=N'Geolocation'),
        @Translation bigint=(SELECT lote FROM @Ids WHERE fuente=N'ProductCategoryTranslation');

INSERT stg.Orders(batch_id,source_row_number,order_id,customer_id,order_status,order_purchase_timestamp,
    order_estimated_delivery_date,order_delivered_customer_date)
VALUES (@Orders,1,'SYN-001','C-01','delivered','2018-01-01T10:00:00','2018-01-05','2018-01-05T22:00:00'),
       (@Orders,2,'SYN-002','C-02','shipped','2018-01-01T09:00:00','2018-01-12',NULL),
       (@Orders,3,'SYN-003','C-MISSING','canceled',NULL,NULL,NULL);

INSERT stg.OrderItems(batch_id,source_row_number,order_id,order_item_id,product_id,seller_id,price,freight_value)
VALUES (@Items,1,'SYN-001',1,'P-01','V-01',10,2), (@Items,2,'SYN-001',2,'P-02','V-MISSING',20,3),
       (@Items,3,'SYN-002',1,'P-MISSING','V-01',5,1);

INSERT stg.OrderPayments(batch_id,source_row_number,order_id,payment_sequential,payment_value)
VALUES (@Payments,1,'SYN-001',1,6), (@Payments,2,'SYN-001',2,6), (@Payments,3,'SYN-002',1,2.5);

INSERT stg.OrderReviews(batch_id,source_row_number,review_id,order_id,review_score)
VALUES (@Reviews,1,'R-REPETIDA','SYN-001',5), (@Reviews,2,'R-REPETIDA','SYN-001',3),
       (@Reviews,3,'R-REPETIDA','SYN-002',2), (@Reviews,4,'R-INVALIDA','SYN-001',6),
       (@Reviews,5,'R-SIN-PUNTAJE','SYN-003',NULL);

INSERT stg.Customers(batch_id,source_row_number,customer_id,customer_unique_id,customer_city,customer_state)
VALUES (@Customers,1,'C-01','CU-01',N'São Paulo','SP'), (@Customers,2,'C-02','CU-01',N'Curitiba','PR');

INSERT stg.Sellers(batch_id,source_row_number,seller_id,seller_city,seller_state)
VALUES (@Sellers,1,'V-01',N'São Paulo','SP');
INSERT stg.Products(batch_id,source_row_number,product_id,product_category_name)
VALUES (@Products,1,'P-01',N'beleza_saude'), (@Products,2,'P-02',NULL);
INSERT stg.Geolocation(batch_id,source_row_number,geolocation_zip_code_prefix,geolocation_city,geolocation_state)
VALUES (@Geo,1,'01234',N'São Paulo','SP'), (@Geo,2,'01234',N'Duplicado sintético','SP');
INSERT stg.ProductCategoryTranslation(batch_id,source_row_number,product_category_name,product_category_name_english)
VALUES (@Translation,1,N'beleza_saude',N'health_beauty');

UPDATE b SET status='COMPLETE', finished_at=SYSDATETIME(), rows_read=v.filas, rows_accepted=v.filas
FROM audit.Batch AS b JOIN (VALUES (@Orders,3), (@Items,3), (@Payments,3), (@Reviews,5),
    (@Customers,2), (@Sellers,1), (@Products,2), (@Geo,2), (@Translation,1)) AS v(lote,filas) ON b.batch_id=v.lote;

INSERT audit.Batch(source_name, status) VALUES (N'OrderItems','RUNNING');
DECLARE @ItemsHuerfanos bigint=SCOPE_IDENTITY();
INSERT stg.OrderItems(batch_id,source_row_number,order_id,order_item_id,price,freight_value)
VALUES (@ItemsHuerfanos,1,'SYN-NOT-FOUND',1,10,2);
UPDATE audit.Batch SET status='COMPLETE', finished_at=SYSDATETIME(), rows_read=1, rows_accepted=1
WHERE batch_id=@ItemsHuerfanos;
COMMIT TRANSACTION;

DECLARE @Lotes nvarchar(400) = (
    SELECT @Orders AS Orders, @Items AS OrderItems, @Payments AS OrderPayments, @Reviews AS OrderReviews,
           @Customers AS Customers, @Sellers AS Sellers, @Products AS Products, @Geo AS Geolocation,
           @Translation AS ProductCategoryTranslation FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
);
SELECT @Lotes AS lotes_validos, JSON_MODIFY(@Lotes,'$.OrderItems',@ItemsHuerfanos) AS lotes_con_huerfano;
