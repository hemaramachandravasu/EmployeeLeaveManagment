/*
  Backup & Security Ops - Schema
  Database: EmployeeLeaveDb
  Creates config/log tables and ensures FULL recovery model for PITR.
*/
USE EmployeeLeaveDb;
GO

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

/* -------------------- Config -------------------- */
IF OBJECT_ID(N'dbo.BackupConfig', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BackupConfig
    (
        ConfigId          INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        DatabaseName      SYSNAME NOT NULL,
        BackupRootPath    NVARCHAR(260) NOT NULL,
        FullRetentionDays INT NOT NULL CONSTRAINT DF_BackupConfig_FullRet DEFAULT (14),
        DiffRetentionDays INT NOT NULL CONSTRAINT DF_BackupConfig_DiffRet DEFAULT (7),
        LogRetentionDays  INT NOT NULL CONSTRAINT DF_BackupConfig_LogRet DEFAULT (3),
        VerifyAfterBackup BIT NOT NULL CONSTRAINT DF_BackupConfig_Verify DEFAULT (1),
        IsEnabled         BIT NOT NULL CONSTRAINT DF_BackupConfig_Enabled DEFAULT (1),
        LastModifiedUtc   DATETIME2 NOT NULL CONSTRAINT DF_BackupConfig_Modified DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_BackupConfig_Database UNIQUE (DatabaseName),
        CONSTRAINT CK_BackupConfig_Paths CHECK (LEN(BackupRootPath) >= 3)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.BackupConfig WHERE DatabaseName = N'EmployeeLeaveDb')
BEGIN
    INSERT INTO dbo.BackupConfig (DatabaseName, BackupRootPath, FullRetentionDays, DiffRetentionDays, LogRetentionDays, VerifyAfterBackup, IsEnabled)
    VALUES (N'EmployeeLeaveDb', N'C:\Backup\EmployeeLeaveDb\', 14, 7, 3, 1, 1);
END
GO

/* -------------------- Run / validation / access logs -------------------- */
IF OBJECT_ID(N'dbo.BackupRunLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BackupRunLog
    (
        BackupRunId     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        DatabaseName    SYSNAME NOT NULL,
        BackupType      NVARCHAR(20) NOT NULL,   -- Full / Differential / Log
        BackupPath      NVARCHAR(520) NOT NULL,
        StartTime       DATETIME2 NOT NULL CONSTRAINT DF_BackupRunLog_Start DEFAULT (SYSUTCDATETIME()),
        EndTime         DATETIME2 NULL,
        Status          NVARCHAR(20) NOT NULL,   -- Running / Success / Failed / Verified
        BackupSizeMB    DECIMAL(18,2) NULL,
        Verified        BIT NOT NULL CONSTRAINT DF_BackupRunLog_Verified DEFAULT (0),
        DurationSeconds INT NULL,
        ErrorMessage    NVARCHAR(4000) NULL
    );

    CREATE INDEX IX_BackupRunLog_Start ON dbo.BackupRunLog (StartTime DESC) INCLUDE (BackupType, Status);
END
GO

IF OBJECT_ID(N'dbo.RecoveryValidationLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.RecoveryValidationLog
    (
        ValidationId     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        DatabaseName     SYSNAME NOT NULL,
        ValidationType   NVARCHAR(50) NOT NULL,  -- VerifyOnly / RestoreDryRun / Integrity
        BackupPath       NVARCHAR(520) NULL,
        TargetPointInTime DATETIME2 NULL,
        StartTime        DATETIME2 NOT NULL CONSTRAINT DF_RecoveryValidation_Start DEFAULT (SYSUTCDATETIME()),
        EndTime          DATETIME2 NULL,
        Status           NVARCHAR(20) NOT NULL,
        Details          NVARCHAR(1000) NULL,
        ErrorMessage     NVARCHAR(4000) NULL
    );
END
GO

IF OBJECT_ID(N'dbo.OpsAlertLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.OpsAlertLog
    (
        AlertId       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        AlertType     NVARCHAR(50) NOT NULL,   -- Storage / FailedJob / BackupLag / LongTx
        Severity      NVARCHAR(20) NOT NULL,   -- Info / Warning / Critical
        MessageText   NVARCHAR(1000) NOT NULL,
        MetricValue   DECIMAL(18,2) NULL,
        ThresholdValue DECIMAL(18,2) NULL,
        CapturedAt    DATETIME2 NOT NULL CONSTRAINT DF_OpsAlertLog_Captured DEFAULT (SYSUTCDATETIME()),
        IsAcknowledged BIT NOT NULL CONSTRAINT DF_OpsAlertLog_Ack DEFAULT (0)
    );

    CREATE INDEX IX_OpsAlertLog_Captured ON dbo.OpsAlertLog (CapturedAt DESC) INCLUDE (AlertType, Severity);
END
GO

IF OBJECT_ID(N'dbo.DbAccessAuditLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DbAccessAuditLog
    (
        AccessAuditId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        CapturedAt    DATETIME2 NOT NULL CONSTRAINT DF_DbAccessAudit_Captured DEFAULT (SYSUTCDATETIME()),
        LoginName     NVARCHAR(128) NULL,
        HostName      NVARCHAR(128) NULL,
        ProgramName   NVARCHAR(128) NULL,
        DatabaseName  SYSNAME NULL,
        SessionId     INT NULL,
        Status        NVARCHAR(30) NULL,
        LoginTime     DATETIME2 NULL,
        LastRequestEndTime DATETIME2 NULL
    );
END
GO

/* Ensure FULL recovery model for PITR (transaction log backups) */
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'EmployeeLeaveDb' AND recovery_model_desc <> N'FULL')
BEGIN
    ALTER DATABASE EmployeeLeaveDb SET RECOVERY FULL;
END
GO

PRINT 'Backup/Security ops schema ready.';
GO
