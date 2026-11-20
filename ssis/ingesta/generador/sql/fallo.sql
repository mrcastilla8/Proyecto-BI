SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @batch bigint=(SELECT batch_id FROM #Lote);
BEGIN TRAN;
UPDATE audit.Batch SET status='RUNNING',started_at=DATEADD(second,1,started_at),
    finished_at=NULL,error_message=NULL WHERE batch_id=@batch AND status='FAILED';
UPDATE audit.Batch SET status='FAILED',
    finished_at=CASE WHEN SYSDATETIME()<started_at THEN started_at ELSE SYSDATETIME() END,
    error_message=N'DATA_FLOW: consultar el log de ejecución.',
    execution_context=CONCAT('SSIS {{FUENTE}}; SPID=',@@SPID)
WHERE batch_id=@batch AND status IN ('PENDING','RUNNING');
COMMIT;
THROW 51924,'DATA_FLOW: falló el flujo SSIS',1;
