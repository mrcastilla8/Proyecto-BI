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
  CONSTRAINT CK_Batch_counts CHECK(rows_read>=0 AND rows_accepted>=0 AND rows_rejected>=0 AND rows_read=rows_accepted+rows_rejected),
  CONSTRAINT CK_Batch_dates CHECK(finished_at IS NULL OR finished_at>=started_at),
  CONSTRAINT CK_Batch_hash CHECK(source_sha256 IS NULL OR source_sha256 NOT LIKE '%[^0-9a-fA-F]%')
 );
END;
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
