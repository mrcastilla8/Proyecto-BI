-- Sustituir los IDs por los de la ejecución que se esté documentando.
SET NOCOUNT ON;
IF COALESCE(CONVERT(int,SERVERPROPERTY('IsLocalDB')),0)<>1 OR DB_NAME()<>'BI_OLIST'
    THROW 51900,'Conecta a la base BI_OLIST de LocalDB.',1;

WITH staging AS (
    SELECT 40011 lote,COUNT_BIG(*) filas FROM stg.Orders WHERE batch_id=40011
    UNION ALL SELECT 40012,COUNT_BIG(*) FROM stg.OrderItems WHERE batch_id=40012
    UNION ALL SELECT 40013,COUNT_BIG(*) FROM stg.OrderPayments WHERE batch_id=40013
    UNION ALL SELECT 40014,COUNT_BIG(*) FROM stg.OrderReviews WHERE batch_id=40014
    UNION ALL SELECT 40015,COUNT_BIG(*) FROM stg.Customers WHERE batch_id=40015
    UNION ALL SELECT 40016,COUNT_BIG(*) FROM stg.Sellers WHERE batch_id=40016
    UNION ALL SELECT 40017,COUNT_BIG(*) FROM stg.Products WHERE batch_id=40017
    UNION ALL SELECT 40018,COUNT_BIG(*) FROM stg.Geolocation WHERE batch_id=40018
    UNION ALL SELECT 40019,COUNT_BIG(*) FROM stg.ProductCategoryTranslation WHERE batch_id=40019
)
SELECT b.batch_id lote,b.source_name fuente,b.status estado,b.rows_read leidas,b.rows_accepted aceptadas,
       b.rows_rejected rechazadas,s.filas staging,
       CASE WHEN b.rows_read=b.rows_accepted+b.rows_rejected AND b.rows_accepted=s.filas
              AND b.rows_rejected=b.rejection_records THEN 'SI' ELSE 'NO' END concilia
FROM staging s INNER JOIN audit.vw_BatchStatus b ON b.batch_id=s.lote ORDER BY lote;

SELECT (SELECT SUM(n-1) FROM (
            SELECT COUNT_BIG(*) n FROM stg.Geolocation WHERE batch_id=40018 GROUP BY
                geolocation_zip_code_prefix,geolocation_lat,geolocation_lng,
                geolocation_city COLLATE Latin1_General_100_BIN2,geolocation_state
        ) geo) geolocation_duplicadas,
       (SELECT COUNT_BIG(*)-COUNT_BIG(DISTINCT review_id) FROM stg.OrderReviews WHERE batch_id=40014) review_id_repetidos,
       (SELECT COUNT_BIG(*) FROM stg.OrderReviews WHERE batch_id=40014 AND
            (CHARINDEX(NCHAR(10),review_comment_message)>0 OR CHARINDEX(NCHAR(13),review_comment_message)>0 OR
             CHARINDEX(NCHAR(10),review_comment_title)>0 OR CHARINDEX(NCHAR(13),review_comment_title)>0)) resenas_multilinea;

SELECT batch_id lote,source_name fuente,source_row_number ordinal,field_name campo,reason_code codigo
FROM audit.Reject WHERE batch_id BETWEEN 40020 AND 40028 ORDER BY lote,ordinal;
