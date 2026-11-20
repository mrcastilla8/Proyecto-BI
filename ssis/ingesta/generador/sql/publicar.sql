SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @batch bigint, @expected int, @session int, @read int=?;
SELECT @batch=batch_id,@expected=expected,@session=session_id FROM #Lote;
IF @session IS NULL OR @session<>@@SPID THROW 51920,'LOTE_SESSION',1;

BEGIN TRY
    IF @read<>@expected OR @read<>(SELECT COUNT(*) FROM #FilasIngesta)
        OR EXISTS(SELECT 1 FROM #FilasIngesta WHERE source_row_number NOT BETWEEN 1 AND @read)
        THROW 51921,'CSV_RECONCILIATION',1;

    {{CLASIFICAR}}
    BEGIN TRAN;
    DECLARE @started datetime2(0)=SYSDATETIME();
    UPDATE audit.Batch WITH (UPDLOCK,HOLDLOCK) SET
        started_at=CASE WHEN status='FAILED' AND started_at>=@started THEN DATEADD(second,1,started_at) ELSE @started END,
        status='RUNNING',finished_at=NULL,error_message=NULL,rows_read=0,rows_accepted=0,rows_rejected=0
    WHERE batch_id=@batch AND status IN ('PENDING','RUNNING','FAILED');
    IF @@ROWCOUNT<>1 THROW 51922,'BATCH_STATE',1;

    DELETE {{TABLA}} WHERE batch_id=@batch;
    DELETE audit.Reject WHERE batch_id=@batch;
    INSERT {{TABLA}}(batch_id,source_row_number,{{CAMPOS}})
    SELECT @batch,source_row_number,{{CONVERTIDOS}}
    FROM #Clasificadas WHERE reason_code IS NULL;
    DECLARE @accepted int=@@ROWCOUNT;
    {{FALLO_INYECTADO}}

    INSERT audit.Reject(batch_id,source_name,source_row_number,field_name,reason_code,reason)
    SELECT @batch,N'{{FUENTE}}',source_row_number,field_name,reason_code,
        CASE reason_code WHEN 'REQUIRED' THEN N'Campo requerido vacío'
            WHEN 'TEXT_LENGTH' THEN N'Texto excede la longitud contractual'
            WHEN 'TEXT_CODEPAGE' THEN N'Texto no representable en el destino'
            WHEN 'ZIP_FORMAT' THEN N'Prefijo postal inválido'
            WHEN 'DATETIME_FORMAT' THEN N'Fecha u hora inválida'
            WHEN 'DECIMAL_SCALE' THEN N'Exceso de decimales para el destino'
            WHEN 'REVIEW_SCORE_RANGE' THEN N'Puntuación fuera de 1 a 5'
            ELSE N'Número inválido para el tipo de destino' END
    FROM #Clasificadas WHERE reason_code IS NOT NULL;
    DECLARE @rejected int=@@ROWCOUNT;
    IF @read<>@accepted+@rejected THROW 51923,'BATCH_RECONCILIATION',1;

    UPDATE audit.Batch SET status='COMPLETE',
        finished_at=CASE WHEN SYSDATETIME()<started_at THEN started_at ELSE SYSDATETIME() END,
        rows_read=@read, rows_accepted=@accepted, rows_rejected=@rejected,
        execution_context=CONCAT('SSIS {{FUENTE}}; SPID=',@@SPID)
    WHERE batch_id=@batch;
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    DECLARE @error int=ERROR_NUMBER();
    BEGIN TRAN;
    UPDATE audit.Batch SET status='RUNNING',started_at=DATEADD(second,1,started_at),
        finished_at=NULL,error_message=NULL WHERE batch_id=@batch AND status='FAILED';
    UPDATE audit.Batch SET status='FAILED',
        finished_at=CASE WHEN SYSDATETIME()<started_at THEN started_at ELSE SYSDATETIME() END,
        error_message=CONCAT('PUBLICAR/',@error),
        execution_context=CONCAT('SSIS {{FUENTE}}; SPID=',@@SPID)
    WHERE batch_id=@batch AND status IN ('PENDING','RUNNING');
    COMMIT;
    THROW;
END CATCH;
