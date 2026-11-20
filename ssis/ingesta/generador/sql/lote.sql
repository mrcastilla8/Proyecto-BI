SET NOCOUNT ON;
DECLARE @hash char(64)=?, @expected int=?, @lock int;
DECLARE @resource nvarchar(255)=CONCAT('BIOLIST:ingesta:{{FUENTE}}:',@hash,':{{VERSION}}');
EXEC @lock=sys.sp_getapplock @Resource=@resource,@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=5000;
IF @lock<0 THROW 51910,'BATCH_LOCK_TIMEOUT',1;

DECLARE @matches int,@batch bigint,@status varchar(12);
SELECT @matches=COUNT(*),@batch=MAX(batch_id),@status=MAX(status)
FROM audit.Batch
WHERE source_name=N'{{FUENTE}}' AND source_file=N'{{ARCHIVO}}'
  AND source_sha256=@hash AND contract_version='{{VERSION}}';
IF @matches>1 THROW 51911,'BATCH_AMBIGUOUS',1;
IF @matches=0
BEGIN
    INSERT audit.Batch(source_name,source_file,source_sha256,contract_version,status)
    VALUES(N'{{FUENTE}}',N'{{ARCHIVO}}',@hash,'{{VERSION}}','PENDING');
    SET @batch=SCOPE_IDENTITY();
END;
INSERT #Lote VALUES(@batch,@expected,@@SPID);
SELECT CONVERT(int,CASE WHEN @status='COMPLETE' THEN 1 ELSE 0 END) AS omit;
