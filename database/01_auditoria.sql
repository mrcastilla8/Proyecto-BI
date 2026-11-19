USE BI_OLIST;
GO
IF OBJECT_ID(N'audit.Batch', N'U') IS NULL
BEGIN
 CREATE TABLE audit.Batch(
  batch_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_audit_Batch PRIMARY KEY,
  source_name NVARCHAR(260) NOT NULL,
  source_file NVARCHAR(260) NULL,
  source_sha256 CHAR(64) NULL,
  contract_version VARCHAR(20) NOT NULL CONSTRAINT DF_Batch_contract DEFAULT('1.0.0'),
  status VARCHAR(12) NOT NULL CONSTRAINT DF_Batch_status DEFAULT('PENDING'),
  started_at DATETIME2(0) NOT NULL CONSTRAINT DF_Batch_started DEFAULT(SYSDATETIME()),
  finished_at DATETIME2(0) NULL,
  rows_read BIGINT NOT NULL CONSTRAINT DF_Batch_read DEFAULT(0),
  rows_accepted BIGINT NOT NULL CONSTRAINT DF_Batch_accepted DEFAULT(0),
  rows_rejected BIGINT NOT NULL CONSTRAINT DF_Batch_rejected DEFAULT(0),
  error_message NVARCHAR(2000) NULL,
  execution_context NVARCHAR(500) NULL,
  CONSTRAINT CK_Batch_status CHECK(status IN ('PENDING','RUNNING','COMPLETE','FAILED')),
  CONSTRAINT CK_Batch_counts CHECK(rows_read>=0 AND rows_accepted>=0 AND rows_rejected>=0 AND rows_read>=rows_accepted+rows_rejected AND (status<>'COMPLETE' OR rows_read=rows_accepted+rows_rejected)),
  CONSTRAINT CK_Batch_finalized CHECK((status IN ('PENDING','RUNNING') AND finished_at IS NULL) OR (status IN ('COMPLETE','FAILED') AND finished_at IS NOT NULL)),
  CONSTRAINT CK_Batch_dates CHECK(finished_at IS NULL OR finished_at>=started_at),
  CONSTRAINT CK_Batch_hash CHECK(source_sha256 IS NULL OR source_sha256 NOT LIKE '%[^0-9a-fA-F]%')
 );
END;
/* Migración aditiva para bases creadas por la versión previa del script. */
IF EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'audit.Batch') AND name=N'CK_Batch_counts')
 ALTER TABLE audit.Batch DROP CONSTRAINT CK_Batch_counts;
ALTER TABLE audit.Batch WITH CHECK ADD CONSTRAINT CK_Batch_counts
 CHECK(rows_read>=0 AND rows_accepted>=0 AND rows_rejected>=0 AND rows_read>=rows_accepted+rows_rejected AND (status<>'COMPLETE' OR rows_read=rows_accepted+rows_rejected));
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'audit.Batch') AND name=N'CK_Batch_finalized')
 ALTER TABLE audit.Batch WITH CHECK ADD CONSTRAINT CK_Batch_finalized
 CHECK((status IN ('PENDING','RUNNING') AND finished_at IS NULL) OR (status IN ('COMPLETE','FAILED') AND finished_at IS NOT NULL));
IF OBJECT_ID(N'audit.Reject', N'U') IS NULL
BEGIN
 CREATE TABLE audit.Reject(
  reject_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_audit_Reject PRIMARY KEY,
  batch_id BIGINT NOT NULL,
  source_name NVARCHAR(260) NOT NULL,
  source_row_number BIGINT NULL,
  source_record_id NVARCHAR(128) NULL,
  field_name SYSNAME NULL,
  reason_code VARCHAR(64) NOT NULL,
  reason NVARCHAR(1000) NOT NULL,
  rejected_at DATETIME2(0) NOT NULL CONSTRAINT DF_Reject_at DEFAULT(SYSDATETIME()),
  CONSTRAINT FK_Reject_Batch FOREIGN KEY(batch_id) REFERENCES audit.Batch(batch_id)
 );
 CREATE INDEX IX_Reject_Batch ON audit.Reject(batch_id, source_name);
END;
GO
CREATE OR ALTER TRIGGER audit.trg_Batch_Transition ON audit.Batch
AFTER UPDATE
AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(
  SELECT 1 FROM inserted i INNER JOIN deleted d ON d.batch_id=i.batch_id
  WHERE i.status<>d.status AND NOT(
   (d.status='PENDING' AND i.status IN ('RUNNING','FAILED')) OR
   (d.status='RUNNING' AND i.status IN ('COMPLETE','FAILED')) OR
   (d.status='FAILED' AND i.status='RUNNING')))
  THROW 51030,'Transicion de estado de lote no permitida.',1;
 IF EXISTS(SELECT 1 FROM deleted d JOIN inserted i ON i.batch_id=d.batch_id
           WHERE d.status='FAILED' AND i.status='RUNNING'
             AND (i.finished_at IS NOT NULL OR i.started_at<=d.started_at))
  THROW 51032,'Reinicio FAILED debe limpiar fin y avanzar inicio.',1;
END;
GO
