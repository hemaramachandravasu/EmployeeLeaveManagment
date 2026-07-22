/*
================================================================================
  Partition AuditLogs onto PS_AuditByChangedOn (ChangedOn)
  Database: EmployeeLeaveDb

  AuditLogs is append-only and high-growth. Quarterly partitions enable:
    • Partition elimination for date-filtered audit reports
    • SWITCH of aged quarters into AuditLogsArchive staging (optional)
================================================================================
*/
USE EmployeeLeaveDb;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS (
    SELECT 1
    FROM sys.indexes i
    INNER JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
    WHERE i.object_id = OBJECT_ID(N'dbo.AuditLogs')
      AND i.index_id IN (0, 1)
      AND ps.name = N'PS_AuditByChangedOn')
BEGIN
    PRINT 'AuditLogs is already partitioned on PS_AuditByChangedOn — skipping.';
END
ELSE
BEGIN
BEGIN TRY
    BEGIN TRAN;

    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.AuditLogs') AND name = N'IX_AuditLogs_Table_ChangedOn')
        DROP INDEX IX_AuditLogs_Table_ChangedOn ON dbo.AuditLogs;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.AuditLogs') AND name = N'IX_AuditLogs_RecordId')
        DROP INDEX IX_AuditLogs_RecordId ON dbo.AuditLogs;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.AuditLogs') AND name = N'IX_AuditLogs_ChangedOn_Action')
        DROP INDEX IX_AuditLogs_ChangedOn_Action ON dbo.AuditLogs;

    DECLARE @PkName SYSNAME =
        (SELECT kc.name
         FROM sys.key_constraints kc
         WHERE kc.parent_object_id = OBJECT_ID(N'dbo.AuditLogs')
           AND kc.type = N'PK');
    IF @PkName IS NOT NULL
        EXEC(N'ALTER TABLE dbo.AuditLogs DROP CONSTRAINT ' + QUOTENAME(@PkName) + N';');

    IF OBJECT_ID(N'dbo.AuditLogs_Partitioned', N'U') IS NOT NULL
        DROP TABLE dbo.AuditLogs_Partitioned;

    CREATE TABLE dbo.AuditLogs_Partitioned
    (
        AuditId    INT IDENTITY(1,1) NOT NULL,
        TableName  NVARCHAR(128) NOT NULL,
        RecordId   INT NOT NULL,
        ActionType NVARCHAR(20) NOT NULL,
        OldValue   NVARCHAR(MAX) NULL,
        NewValue   NVARCHAR(MAX) NULL,
        ChangedBy  NVARCHAR(200) NULL,
        ChangedOn  DATETIME2 NOT NULL CONSTRAINT DF_ALP_ChangedOn DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_AuditLogs PRIMARY KEY CLUSTERED (ChangedOn, AuditId)
            ON PS_AuditByChangedOn (ChangedOn)
    ) ON PS_AuditByChangedOn (ChangedOn);

    SET IDENTITY_INSERT dbo.AuditLogs_Partitioned ON;

    INSERT INTO dbo.AuditLogs_Partitioned
        (AuditId, TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy, ChangedOn)
    SELECT
        AuditId, TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy, ChangedOn
    FROM dbo.AuditLogs WITH (TABLOCKX);

    SET IDENTITY_INSERT dbo.AuditLogs_Partitioned OFF;

    DECLARE @Copied INT = @@ROWCOUNT;

    EXEC sp_rename N'dbo.AuditLogs', N'AuditLogs_Old_Unpartitioned';
    EXEC sp_rename N'dbo.AuditLogs_Partitioned', N'AuditLogs';

    DROP TABLE dbo.AuditLogs_Old_Unpartitioned;

    /* Unique ID lookup is non-aligned so seeks by AuditId alone stay efficient */
    CREATE UNIQUE NONCLUSTERED INDEX UQ_AuditLogs_AuditId
        ON dbo.AuditLogs (AuditId);

    CREATE NONCLUSTERED INDEX IX_AuditLogs_Table_ChangedOn
        ON dbo.AuditLogs (TableName, ChangedOn)
        INCLUDE (RecordId, ActionType, ChangedBy)
        ON PS_AuditByChangedOn (ChangedOn);

    CREATE NONCLUSTERED INDEX IX_AuditLogs_RecordId
        ON dbo.AuditLogs (RecordId)
        INCLUDE (TableName, ActionType, ChangedOn)
        ON PS_AuditByChangedOn (ChangedOn);

    CREATE NONCLUSTERED INDEX IX_AuditLogs_ChangedOn_Action
        ON dbo.AuditLogs (ChangedOn, ActionType)
        INCLUDE (TableName, RecordId, ChangedBy)
        ON PS_AuditByChangedOn (ChangedOn);

    DECLARE @MaxId INT = (SELECT ISNULL(MAX(AuditId), 0) FROM dbo.AuditLogs);
    DBCC CHECKIDENT (N'dbo.AuditLogs', RESEED, @MaxId);

    COMMIT TRAN;

    INSERT INTO dbo.OptimizationRunLog (JobName, StepName, EndTime, Status, Details)
    VALUES (N'Partition_AuditLogs', N'Migrate', SYSUTCDATETIME(), N'Success',
            N'Copied ' + CAST(@Copied AS NVARCHAR(20)) + N' rows onto PS_AuditByChangedOn.');

    PRINT 'AuditLogs partitioned successfully. Rows copied: ' + CAST(@Copied AS VARCHAR(20));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;

    INSERT INTO dbo.OptimizationRunLog (JobName, StepName, EndTime, Status, ErrorMessage)
    VALUES (N'Partition_AuditLogs', N'Migrate', SYSUTCDATETIME(), N'Failed', ERROR_MESSAGE());

    THROW;
END CATCH
END
GO
