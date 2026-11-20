-- Ejecutar en BI_OLIST_VALIDACION_TEXTO de la instancia LocalDB.
SET NOCOUNT ON;
IF COALESCE(CONVERT(int,SERVERPROPERTY('IsLocalDB')),0)<>1 OR DB_NAME()<>N'BI_OLIST_VALIDACION_TEXTO'
    THROW 51970,'Selecciona la base aislada de validación de texto.',1;

DECLARE @hash char(64)='012b61c7593e34f51fa614efdf802b9c7056ce6aae5307ddb93236e7cfc797d7';
DECLARE @antes bigint=(SELECT batch_id FROM BI_OLIST.audit.Batch
    WHERE source_name=N'OrderReviews' AND status='COMPLETE' AND source_sha256=@hash AND contract_version='1.0.0');
DECLARE @ahora bigint=(SELECT batch_id FROM audit.Batch
    WHERE source_name=N'OrderReviews' AND status='COMPLETE' AND source_sha256=@hash AND contract_version='1.0.0');
IF @antes IS NULL OR @ahora IS NULL THROW 51971,'No se localizaron ambos lotes auténticos.',1;
SELECT @antes lote_historico,@ahora lote_corregido;
SELECT f.campo,
    SUM(CASE WHEN f.anterior IS NULL AND DATALENGTH(f.nuevo)>0 THEN 1 ELSE 0 END) nulos_anterior_restaurados,
    SUM(CASE WHEN f.anterior IS NULL AND DATALENGTH(f.nuevo)=2 AND CONVERT(varbinary(max),f.nuevo)=0x2000 THEN 1 ELSE 0 END) espacios_ascii_restaurados,
    SUM(CASE WHEN f.anterior IS NOT NULL AND (f.nuevo IS NULL OR DATALENGTH(f.anterior)<>DATALENGTH(f.nuevo)
        OR HASHBYTES('SHA2_256',f.anterior)<>HASHBYTES('SHA2_256',f.nuevo)) THEN 1 ELSE 0 END) diferencias_en_campos_antes_no_nulos
FROM BI_OLIST.stg.OrderReviews prior
JOIN stg.OrderReviews fixed ON fixed.batch_id=@ahora AND fixed.source_row_number=prior.source_row_number
CROSS APPLY (VALUES ('titulo',prior.review_comment_title,fixed.review_comment_title),
    ('mensaje',prior.review_comment_message,fixed.review_comment_message)) f(campo,anterior,nuevo)
WHERE prior.batch_id=@antes
GROUP BY f.campo ORDER BY f.campo;
