/*
================================================================================
  Employee Leave Management — Archive & Maintenance Schema
  Database: EmployeeLeaveDb
================================================================================
*/
USE EmployeeLeaveDb;
GO

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* --------------------------------------------------------------------------
   1) Operational tables required for archival (idempotent)
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.Notifications', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Notifications (
        NotificationId   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        EmployeeId       INT NOT NULL,
        Title            NVARCHAR(200) NOT NULL,
        MessageBody      NVARCHAR(1000) NOT NULL,
        NotificationType NVARCHAR(50) NOT NULL CONSTRAINT DF_Notifications_Type DEFAULT (N'Info'),
        IsRead           BIT NOT NULL CONSTRAINT DF_Notifications_IsRead DEFAULT (0),
        CreatedAt        DATETIME2 NOT NULL CONSTRAINT DF_Notifications_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_Notifications_Employee FOREIGN KEY (EmployeeId) REFERENCES dbo.Employees(EmployeeId)
    );

    CREATE NONCLUSTERED INDEX IX_Notifications_Employee_CreatedAt
        ON dbo.Notifications(EmployeeId, CreatedAt) INCLUDE (IsRead, NotificationType);
END
GO

IF OBJECT_ID(N'dbo.LeaveBalances', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LeaveBalances (
        LeaveBalanceId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        EmployeeId     INT NOT NULL,
        LeaveTypeId    INT NOT NULL,
        BalanceYear    INT NOT NULL,
        EntitledDays   DECIMAL(9,2) NOT NULL CONSTRAINT DF_LeaveBalances_Entitled DEFAULT (0),
        UsedDays       DECIMAL(9,2) NOT NULL CONSTRAINT DF_LeaveBalances_Used DEFAULT (0),
        RemainingDays  AS (EntitledDays - UsedDays) PERSISTED,
        IsHistorical   BIT NOT NULL CONSTRAINT DF_LeaveBalances_IsHistorical DEFAULT (0),
        CreatedAt      DATETIME2 NOT NULL CONSTRAINT DF_LeaveBalances_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ClosedAt       DATETIME2 NULL,
        CONSTRAINT FK_LeaveBalances_Employee FOREIGN KEY (EmployeeId) REFERENCES dbo.Employees(EmployeeId),
        CONSTRAINT FK_LeaveBalances_LeaveType FOREIGN KEY (LeaveTypeId) REFERENCES dbo.LeaveTypes(LeaveTypeId),
        CONSTRAINT UQ_LeaveBalances_EmpTypeYear UNIQUE (EmployeeId, LeaveTypeId, BalanceYear)
    );

    CREATE NONCLUSTERED INDEX IX_LeaveBalances_Year_Historical
        ON dbo.LeaveBalances(BalanceYear, IsHistorical) INCLUDE (EmployeeId, LeaveTypeId, UsedDays);
END
GO

/* Ensure LeaveRequestsArchive exists with full column set */
IF OBJECT_ID(N'dbo.LeaveRequestsArchive', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LeaveRequestsArchive (
        ArchiveId      BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        LeaveRequestId INT NOT NULL,
        EmployeeId     INT NOT NULL,
        LeaveTypeId    INT NOT NULL,
        StartDate      DATE NOT NULL,
        EndDate        DATE NOT NULL,
        TotalDays      INT NOT NULL,
        Reason         NVARCHAR(500) NOT NULL,
        Status         NVARCHAR(50) NOT NULL,
        ApprovedBy     INT NULL,
        ApprovedDate   DATETIME2 NULL,
        Remarks        NVARCHAR(500) NULL,
        IsCancelled    BIT NOT NULL,
        CreatedDate    DATETIME2 NOT NULL,
        ModifiedDate   DATETIME2 NULL,
        ArchivedAt     DATETIME2 NOT NULL CONSTRAINT DF_LeaveRequestsArchive_ArchivedAt DEFAULT (SYSUTCDATETIME()),
        ArchiveBatchId UNIQUEIDENTIFIER NOT NULL
    );
END
ELSE
BEGIN
    IF COL_LENGTH(N'dbo.LeaveRequestsArchive', N'ArchiveBatchId') IS NULL
        ALTER TABLE dbo.LeaveRequestsArchive ADD ArchiveBatchId UNIQUEIDENTIFIER NULL;

    IF COL_LENGTH(N'dbo.LeaveRequestsArchive', N'ArchiveId') IS NULL
        ALTER TABLE dbo.LeaveRequestsArchive ADD ArchiveId BIGINT IDENTITY(1,1) NOT NULL;
END
GO

IF OBJECT_ID(N'dbo.NotificationsArchive', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.NotificationsArchive (
        ArchiveId        BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        NotificationId   INT NOT NULL,
        EmployeeId       INT NOT NULL,
        Title            NVARCHAR(200) NOT NULL,
        MessageBody      NVARCHAR(1000) NOT NULL,
        NotificationType NVARCHAR(50) NOT NULL,
        IsRead           BIT NOT NULL,
        CreatedAt        DATETIME2 NOT NULL,
        ArchivedAt       DATETIME2 NOT NULL CONSTRAINT DF_NotificationsArchive_ArchivedAt DEFAULT (SYSUTCDATETIME()),
        ArchiveBatchId   UNIQUEIDENTIFIER NOT NULL
    );

    CREATE NONCLUSTERED INDEX IX_NotificationsArchive_CreatedAt
        ON dbo.NotificationsArchive(CreatedAt) INCLUDE (EmployeeId, NotificationType);
END
GO

IF OBJECT_ID(N'dbo.AuditLogsArchive', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditLogsArchive (
        ArchiveId    BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        AuditId      INT NOT NULL,
        TableName    NVARCHAR(128) NOT NULL,
        RecordId     INT NOT NULL,
        ActionType   NVARCHAR(20) NOT NULL,
        OldValue     NVARCHAR(MAX) NULL,
        NewValue     NVARCHAR(MAX) NULL,
        ChangedBy    NVARCHAR(200) NULL,
        ChangedOn    DATETIME2 NOT NULL,
        ArchivedAt   DATETIME2 NOT NULL CONSTRAINT DF_AuditLogsArchive_ArchivedAt DEFAULT (SYSUTCDATETIME()),
        ArchiveBatchId UNIQUEIDENTIFIER NOT NULL
    );

    CREATE NONCLUSTERED INDEX IX_AuditLogsArchive_ChangedOn
        ON dbo.AuditLogsArchive(ChangedOn) INCLUDE (TableName, ActionType);
END
GO

IF OBJECT_ID(N'dbo.LeaveBalancesArchive', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LeaveBalancesArchive (
        ArchiveId      BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        LeaveBalanceId INT NOT NULL,
        EmployeeId     INT NOT NULL,
        LeaveTypeId    INT NOT NULL,
        BalanceYear    INT NOT NULL,
        EntitledDays   DECIMAL(9,2) NOT NULL,
        UsedDays       DECIMAL(9,2) NOT NULL,
        RemainingDays  DECIMAL(9,2) NOT NULL,
        IsHistorical   BIT NOT NULL,
        CreatedAt      DATETIME2 NOT NULL,
        ClosedAt       DATETIME2 NULL,
        ArchivedAt     DATETIME2 NOT NULL CONSTRAINT DF_LeaveBalancesArchive_ArchivedAt DEFAULT (SYSUTCDATETIME()),
        ArchiveBatchId UNIQUEIDENTIFIER NOT NULL
    );

    CREATE NONCLUSTERED INDEX IX_LeaveBalancesArchive_Year
        ON dbo.LeaveBalancesArchive(BalanceYear) INCLUDE (EmployeeId, LeaveTypeId);
END
GO

/* --------------------------------------------------------------------------
   2) Retention configuration
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.ArchiveRetentionConfig', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ArchiveRetentionConfig (
        ConfigId         INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        EntityName       NVARCHAR(100) NOT NULL,
        RetentionDays    INT NOT NULL,
        IsEnabled        BIT NOT NULL CONSTRAINT DF_ArchiveRetention_IsEnabled DEFAULT (1),
        Description      NVARCHAR(500) NULL,
        LastModifiedUtc  DATETIME2 NOT NULL CONSTRAINT DF_ArchiveRetention_Modified DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_ArchiveRetention_Entity UNIQUE (EntityName),
        CONSTRAINT CK_ArchiveRetention_Days CHECK (RetentionDays >= 30)
    );
END
GO

MERGE dbo.ArchiveRetentionConfig AS t
USING (VALUES
    (N'LeaveRequests',  730, 1, N'Closed / final leave requests older than retention (default 2 years)'),
    (N'Notifications',  180, 1, N'Read notification records older than retention (default 6 months)'),
    (N'AuditLogs',      365, 1, N'Audit log rows older than retention (default 1 year)'),
    (N'LeaveBalances',  730, 1, N'Historical leave balance rows older than retention (default 2 years)')
) AS s(EntityName, RetentionDays, IsEnabled, Description)
ON t.EntityName = s.EntityName
WHEN NOT MATCHED THEN
    INSERT (EntityName, RetentionDays, IsEnabled, Description)
    VALUES (s.EntityName, s.RetentionDays, s.IsEnabled, s.Description);
GO

/* --------------------------------------------------------------------------
   3) Logging / metrics history
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.ArchiveRunLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ArchiveRunLog (
        ArchiveRunId   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ArchiveBatchId UNIQUEIDENTIFIER NOT NULL,
        EntityName     NVARCHAR(100) NOT NULL,
        StartTime      DATETIME2 NOT NULL CONSTRAINT DF_ArchiveRunLog_Start DEFAULT (SYSUTCDATETIME()),
        EndTime        DATETIME2 NULL,
        Status         NVARCHAR(20) NOT NULL CONSTRAINT DF_ArchiveRunLog_Status DEFAULT (N'Running'),
        RowsArchived   INT NULL,
        RetentionDays  INT NULL,
        ErrorMessage   NVARCHAR(4000) NULL
    );

    CREATE NONCLUSTERED INDEX IX_ArchiveRunLog_StartTime
        ON dbo.ArchiveRunLog(StartTime DESC) INCLUDE (EntityName, Status, RowsArchived);
END
GO

IF OBJECT_ID(N'dbo.MaintenanceRunLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MaintenanceRunLog (
        MaintenanceRunId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        JobName          NVARCHAR(128) NOT NULL,
        StepName         NVARCHAR(128) NOT NULL,
        StartTime        DATETIME2 NOT NULL CONSTRAINT DF_MaintenanceRunLog_Start DEFAULT (SYSUTCDATETIME()),
        EndTime          DATETIME2 NULL,
        Status           NVARCHAR(20) NOT NULL CONSTRAINT DF_MaintenanceRunLog_Status DEFAULT (N'Running'),
        Details          NVARCHAR(MAX) NULL,
        ErrorMessage     NVARCHAR(4000) NULL
    );

    CREATE NONCLUSTERED INDEX IX_MaintenanceRunLog_StartTime
        ON dbo.MaintenanceRunLog(StartTime DESC) INCLUDE (JobName, StepName, Status);
END
GO

IF OBJECT_ID(N'dbo.DatabaseMetricSnapshot', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DatabaseMetricSnapshot (
        SnapshotId       BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        CapturedAt       DATETIME2 NOT NULL CONSTRAINT DF_DbMetric_CapturedAt DEFAULT (SYSUTCDATETIME()),
        MetricCategory   NVARCHAR(50) NOT NULL,
        MetricName       NVARCHAR(128) NOT NULL,
        MetricValue      DECIMAL(18,4) NULL,
        MetricUnit       NVARCHAR(32) NULL,
        ExtraJson        NVARCHAR(MAX) NULL
    );

    CREATE NONCLUSTERED INDEX IX_DatabaseMetricSnapshot_CapturedAt
        ON dbo.DatabaseMetricSnapshot(CapturedAt DESC, MetricCategory) INCLUDE (MetricName, MetricValue);
END
GO

/* Seed sample notifications / balances for demo archival (only when empty) */
IF NOT EXISTS (SELECT 1 FROM dbo.Notifications)
BEGIN
    INSERT INTO dbo.Notifications (EmployeeId, Title, MessageBody, NotificationType, IsRead, CreatedAt)
    SELECT TOP (5)
        e.EmployeeId,
        N'Leave status update',
        N'Your leave request was processed.',
        N'Leave',
        1,
        DATEADD(DAY, -200, SYSUTCDATETIME())
    FROM dbo.Employees e
    WHERE e.IsActive = 1;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.LeaveBalances)
BEGIN
    INSERT INTO dbo.LeaveBalances (EmployeeId, LeaveTypeId, BalanceYear, EntitledDays, UsedDays, IsHistorical, CreatedAt, ClosedAt)
    SELECT TOP (5)
        e.EmployeeId,
        lt.LeaveTypeId,
        YEAR(SYSUTCDATETIME()) - 3,
        20,
        8,
        1,
        DATEADD(YEAR, -3, SYSUTCDATETIME()),
        DATEADD(YEAR, -2, SYSUTCDATETIME())
    FROM dbo.Employees e
    CROSS APPLY (SELECT TOP (1) LeaveTypeId FROM dbo.LeaveTypes ORDER BY LeaveTypeId) lt
    WHERE e.IsActive = 1;
END
GO

PRINT '01_Archive_Schema.sql completed.';
GO
