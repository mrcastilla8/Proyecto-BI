-- Solo lectura. Consulta de los nueve lotes de la carga inicial de BI_OLIST principal.
SET NOCOUNT ON;
IF DB_NAME()<>N'BI_OLIST' OR COALESCE(CONVERT(int,SERVERPROPERTY('IsLocalDB')),0)<>0
    THROW 51980,'Selecciona BI_OLIST de SQL Server principal.',1;

SELECT source_name fuente,batch_id lote,status estado,rows_read leidas,rows_accepted aceptadas,rows_rejected rechazadas
FROM audit.vw_BatchStatus
WHERE batch_id BETWEEN 7 AND 15
ORDER BY batch_id;

WITH staging AS (
    SELECT 7 AS lote, COUNT_BIG(*) AS filas, MIN(source_row_number) AS ordinal_min, MAX(source_row_number) AS ordinal_max FROM stg.Orders WHERE batch_id=7
    UNION ALL SELECT 8, COUNT_BIG(*), MIN(source_row_number), MAX(source_row_number) FROM stg.OrderItems WHERE batch_id=8
    UNION ALL SELECT 9, COUNT_BIG(*), MIN(source_row_number), MAX(source_row_number) FROM stg.OrderPayments WHERE batch_id=9
    UNION ALL SELECT 10, COUNT_BIG(*), MIN(source_row_number), MAX(source_row_number) FROM stg.OrderReviews WHERE batch_id=10
    UNION ALL SELECT 11, COUNT_BIG(*), MIN(source_row_number), MAX(source_row_number) FROM stg.Customers WHERE batch_id=11
    UNION ALL SELECT 12, COUNT_BIG(*), MIN(source_row_number), MAX(source_row_number) FROM stg.Sellers WHERE batch_id=12
    UNION ALL SELECT 13, COUNT_BIG(*), MIN(source_row_number), MAX(source_row_number) FROM stg.Products WHERE batch_id=13
    UNION ALL SELECT 14, COUNT_BIG(*), MIN(source_row_number), MAX(source_row_number) FROM stg.Geolocation WHERE batch_id=14
    UNION ALL SELECT 15, COUNT_BIG(*), MIN(source_row_number), MAX(source_row_number) FROM stg.ProductCategoryTranslation WHERE batch_id=15
)
SELECT b.source_name fuente,b.batch_id lote,s.filas staging,s.ordinal_min,s.ordinal_max,
    CASE WHEN b.status='COMPLETE' AND b.contract_version='1.0.0' AND b.rows_read=b.rows_accepted+b.rows_rejected
        AND s.filas=b.rows_accepted AND s.ordinal_min=1 AND s.ordinal_max=b.rows_read THEN 'SI' ELSE 'NO' END concilia
FROM staging s JOIN audit.Batch b ON b.batch_id=s.lote ORDER BY s.lote;
