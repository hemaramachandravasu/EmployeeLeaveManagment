/*
================================================================================
  Partition LeaveRequests onto PS_LeaveByCreatedDate (CreatedDate)
  Database: EmployeeLeaveDb

  Approach (online-friendly rebuild via staging table):
    1. Detect if already partitioned → skip
    2. Drop audit trigger + FK constraints + NC indexes
    3. Create partitioned staging table with aligned clustered PK
    4. Copy data (IDENTITY_INSERT), swap names
    5. Recreate FKs, covering indexes (partition-aligned), trigger

  Clustered PK includes the partition column (CreatedDate) as required by
  SQL Server for unique indexes on partitioned tables. LeaveRequestId remains
  uniquely searchable via UQ_LeaveRequests_LeaveRequestId.
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
    WHERE i.object_id = OBJECT_ID(N'dbo.LeaveRequests')
      AND i.index_id IN (0, 1)
      AND ps.name = N'PS_LeaveByCreatedDate')
BEGIN
    PRINT 'LeaveRequests is already partitioned on PS_LeaveByCreatedDate — skipping.';
END
ELSE
BEGIN
BEGIN TRY
    BEGIN TRAN;

    /* ---- Drop dependent objects ---- */
    IF OBJECT_ID(N'dbo.trg_LeaveRequests_Audit', N'TR') IS NOT NULL
        DROP TRIGGER dbo.trg_LeaveRequests_Audit;

    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_LeaveRequests_Employee')
        ALTER TABLE dbo.LeaveRequests DROP CONSTRAINT FK_LeaveRequests_Employee;
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_LeaveRequests_LeaveType')
        ALTER TABLE dbo.LeaveRequests DROP CONSTRAINT FK_LeaveRequests_LeaveType;
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_LeaveRequests_ApprovedBy')
        ALTER TABLE dbo.LeaveRequests DROP CONSTRAINT FK_LeaveRequests_ApprovedBy;

    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.LeaveRequests') AND name = N'IX_LeaveRequests_Employee_StartDate')
        DROP INDEX IX_LeaveRequests_Employee_StartDate ON dbo.LeaveRequests;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.LeaveRequests') AND name = N'IX_LeaveRequests_Status_StartDate')
        DROP INDEX IX_LeaveRequests_Status_StartDate ON dbo.LeaveRequests;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.LeaveRequests') AND name = N'IX_LeaveRequests_CreatedDate_Status')
        DROP INDEX IX_LeaveRequests_CreatedDate_Status ON dbo.LeaveRequests;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.LeaveRequests') AND name = N'IX_LeaveRequests_ApprovedBy_ApprovedDate')
        DROP INDEX IX_LeaveRequests_ApprovedBy_ApprovedDate ON dbo.LeaveRequests;

    /* Drop existing PK (name may be system-generated) */
    DECLARE @PkName SYSNAME =
        (SELECT kc.name
         FROM sys.key_constraints kc
         WHERE kc.parent_object_id = OBJECT_ID(N'dbo.LeaveRequests')
           AND kc.type = N'PK');
    IF @PkName IS NOT NULL
        EXEC(N'ALTER TABLE dbo.LeaveRequests DROP CONSTRAINT ' + QUOTENAME(@PkName) + N';');

    /* ---- Staging partitioned table ---- */
    IF OBJECT_ID(N'dbo.LeaveRequests_Partitioned', N'U') IS NOT NULL
        DROP TABLE dbo.LeaveRequests_Partitioned;

    CREATE TABLE dbo.LeaveRequests_Partitioned
    (
        LeaveRequestId INT IDENTITY(1,1) NOT NULL,
        EmployeeId     INT NOT NULL,
        LeaveTypeId    INT NOT NULL,
        StartDate      DATE NOT NULL,
        EndDate        DATE NOT NULL,
        TotalDays      AS (DATEDIFF(DAY, StartDate, EndDate) + 1) PERSISTED,
        Reason         NVARCHAR(500) NOT NULL,
        Status         NVARCHAR(50) NOT NULL CONSTRAINT DF_LRP_Status DEFAULT (N'Pending'),
        ApprovedBy     INT NULL,
        ApprovedDate   DATETIME2 NULL,
        Remarks        NVARCHAR(500) NULL,
        IsCancelled    BIT NOT NULL CONSTRAINT DF_LRP_IsCancelled DEFAULT (0),
        CreatedDate    DATETIME2 NOT NULL CONSTRAINT DF_LRP_CreatedDate DEFAULT (SYSUTCDATETIME()),
        ModifiedDate   DATETIME2 NULL,
        CONSTRAINT PK_LeaveRequests PRIMARY KEY CLUSTERED (CreatedDate, LeaveRequestId)
            ON PS_LeaveByCreatedDate (CreatedDate)
    ) ON PS_LeaveByCreatedDate (CreatedDate);

    SET IDENTITY_INSERT dbo.LeaveRequests_Partitioned ON;

    INSERT INTO dbo.LeaveRequests_Partitioned
    (
        LeaveRequestId, EmployeeId, LeaveTypeId, StartDate, EndDate, Reason, Status,
        ApprovedBy, ApprovedDate, Remarks, IsCancelled, CreatedDate, ModifiedDate
    )
    SELECT
        LeaveRequestId, EmployeeId, LeaveTypeId, StartDate, EndDate, Reason, Status,
        ApprovedBy, ApprovedDate, Remarks, IsCancelled, CreatedDate, ModifiedDate
    FROM dbo.LeaveRequests WITH (TABLOCKX);

    SET IDENTITY_INSERT dbo.LeaveRequests_Partitioned OFF;

    DECLARE @Copied INT = @@ROWCOUNT;

    /* ---- Swap ---- */
    EXEC sp_rename N'dbo.LeaveRequests', N'LeaveRequests_Old_Unpartitioned';
    EXEC sp_rename N'dbo.LeaveRequests_Partitioned', N'LeaveRequests';

    DROP TABLE dbo.LeaveRequests_Old_Unpartitioned;

    /* ---- Unique ID lookup (non-aligned) + covering indexes (aligned) ---- */
    CREATE UNIQUE NONCLUSTERED INDEX UQ_LeaveRequests_LeaveRequestId
        ON dbo.LeaveRequests (LeaveRequestId);

    CREATE NONCLUSTERED INDEX IX_LeaveRequests_Employee_StartDate
        ON dbo.LeaveRequests (EmployeeId, StartDate)
        INCLUDE (EndDate, Status, LeaveTypeId, TotalDays, IsCancelled)
        ON PS_LeaveByCreatedDate (CreatedDate);

    CREATE NONCLUSTERED INDEX IX_LeaveRequests_Status_StartDate
        ON dbo.LeaveRequests (Status, StartDate)
        INCLUDE (EndDate, EmployeeId, LeaveTypeId, IsCancelled, CreatedDate)
        ON PS_LeaveByCreatedDate (CreatedDate);

    CREATE NONCLUSTERED INDEX IX_LeaveRequests_CreatedDate_Status
        ON dbo.LeaveRequests (CreatedDate, Status)
        INCLUDE (EmployeeId, LeaveTypeId, StartDate, EndDate, TotalDays)
        ON PS_LeaveByCreatedDate (CreatedDate);

    CREATE NONCLUSTERED INDEX IX_LeaveRequests_ApprovedBy_ApprovedDate
        ON dbo.LeaveRequests (ApprovedBy, ApprovedDate)
        INCLUDE (Status, EmployeeId, LeaveTypeId)
        WHERE ApprovedBy IS NOT NULL
        ON PS_LeaveByCreatedDate (CreatedDate);

    /* ---- Restore FKs ---- */
    ALTER TABLE dbo.LeaveRequests WITH CHECK
        ADD CONSTRAINT FK_LeaveRequests_Employee
        FOREIGN KEY (EmployeeId) REFERENCES dbo.Employees (EmployeeId);

    ALTER TABLE dbo.LeaveRequests WITH CHECK
        ADD CONSTRAINT FK_LeaveRequests_LeaveType
        FOREIGN KEY (LeaveTypeId) REFERENCES dbo.LeaveTypes (LeaveTypeId);

    ALTER TABLE dbo.LeaveRequests WITH CHECK
        ADD CONSTRAINT FK_LeaveRequests_ApprovedBy
        FOREIGN KEY (ApprovedBy) REFERENCES dbo.Employees (EmployeeId);

    /* ---- Recreate audit trigger ---- */
    EXEC(N'
CREATE TRIGGER dbo.trg_LeaveRequests_Audit
ON dbo.LeaveRequests
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditLogs (TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy)
    SELECT
        N''LeaveRequests'',
        COALESCE(i.LeaveRequestId, d.LeaveRequestId),
        CASE
            WHEN i.LeaveRequestId IS NOT NULL AND d.LeaveRequestId IS NULL THEN N''Insert''
            WHEN i.LeaveRequestId IS NOT NULL AND d.LeaveRequestId IS NOT NULL THEN N''Update''
            ELSE N''Delete''
        END,
        CASE WHEN d.LeaveRequestId IS NULL THEN NULL ELSE (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.LeaveRequestId IS NULL THEN NULL ELSE (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CONCAT(SUSER_SNAME(), N'' | '', APP_NAME())
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.LeaveRequestId = d.LeaveRequestId;
END');

    /* Reseed identity if needed */
    DECLARE @MaxId INT = (SELECT ISNULL(MAX(LeaveRequestId), 0) FROM dbo.LeaveRequests);
    DBCC CHECKIDENT (N'dbo.LeaveRequests', RESEED, @MaxId);

    COMMIT TRAN;

    INSERT INTO dbo.OptimizationRunLog (JobName, StepName, EndTime, Status, Details)
    VALUES (N'Partition_LeaveRequests', N'Migrate', SYSUTCDATETIME(), N'Success',
            N'Copied ' + CAST(@Copied AS NVARCHAR(20)) + N' rows onto PS_LeaveByCreatedDate.');

    PRINT 'LeaveRequests partitioned successfully. Rows copied: ' + CAST(@Copied AS VARCHAR(20));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;

    INSERT INTO dbo.OptimizationRunLog (JobName, StepName, EndTime, Status, ErrorMessage)
    VALUES (N'Partition_LeaveRequests', N'Migrate', SYSUTCDATETIME(), N'Failed', ERROR_MESSAGE());

    THROW;
END CATCH
END
GO
