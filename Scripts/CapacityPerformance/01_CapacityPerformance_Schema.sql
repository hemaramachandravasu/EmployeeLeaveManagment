/*
================================================================================
  Capacity Planning & SQL Performance Dashboard — Schema
  Database: EmployeeLeaveDb
================================================================================
*/
USE EmployeeLeaveDb;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* Reuse / create OpsAlertLog if BackupSecurity not deployed */
IF OBJECT_ID(N'dbo.OpsAlertLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.OpsAlertLog
    (
        AlertId        INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        AlertType      NVARCHAR(50) NOT NULL,
        Severity       NVARCHAR(20) NOT NULL,
        MessageText    NVARCHAR(1000) NOT NULL,
        MetricValue    DECIMAL(18,2) NULL,
        ThresholdValue DECIMAL(18,2) NULL,
        CapturedAt     DATETIME2 NOT NULL CONSTRAINT DF_CP_OpsAlert_Captured DEFAULT (SYSUTCDATETIME()),
        IsAcknowledged BIT NOT NULL CONSTRAINT DF_CP_OpsAlert_Ack DEFAULT (0)
    );
    CREATE INDEX IX_CP_OpsAlertLog_Captured ON dbo.OpsAlertLog (CapturedAt DESC) INCLUDE (AlertType, Severity);
END
GO

/* Reuse / create DatabaseMetricSnapshot if Maintenance not deployed */
IF OBJECT_ID(N'dbo.DatabaseMetricSnapshot', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DatabaseMetricSnapshot
    (
        SnapshotId     BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        CapturedAt     DATETIME2 NOT NULL CONSTRAINT DF_CP_Metric_Captured DEFAULT (SYSUTCDATETIME()),
        MetricCategory NVARCHAR(50) NOT NULL,
        MetricName     NVARCHAR(128) NOT NULL,
        MetricValue    DECIMAL(18,4) NULL,
        MetricUnit     NVARCHAR(32) NULL,
        ExtraJson      NVARCHAR(MAX) NULL
    );
    CREATE INDEX IX_CP_MetricSnapshot_CatAt
        ON dbo.DatabaseMetricSnapshot (MetricCategory, CapturedAt DESC) INCLUDE (MetricName, MetricValue);
END
GO

IF OBJECT_ID(N'dbo.CapacityAlertThreshold', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CapacityAlertThreshold
    (
        ThresholdId    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ThresholdCode  NVARCHAR(50) NOT NULL,
        Description    NVARCHAR(200) NOT NULL,
        WarnValue      DECIMAL(18,2) NOT NULL,
        CritValue      DECIMAL(18,2) NOT NULL,
        Unit           NVARCHAR(20) NOT NULL,
        IsActive       BIT NOT NULL CONSTRAINT DF_CapThresh_Active DEFAULT (1),
        ModifiedAt     DATETIME2 NOT NULL CONSTRAINT DF_CapThresh_Mod DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_CapacityAlertThreshold_Code UNIQUE (ThresholdCode)
    );

    INSERT INTO dbo.CapacityAlertThreshold (ThresholdCode, Description, WarnValue, CritValue, Unit) VALUES
        (N'STORAGE_USED_PCT', N'Database file used percent', 80, 90, N'Percent'),
        (N'VOLUME_FREE_PCT', N'OS volume free percent', 15, 10, N'Percent'),
        (N'INDEX_FRAG_PCT', N'Index fragmentation percent', 30, 50, N'Percent'),
        (N'LONG_QUERY_SEC', N'Long-running query seconds', 60, 180, N'Seconds'),
        (N'CAPACITY_DAYS_LEFT', N'Days until projected capacity full', 90, 30, N'Days'),
        (N'WAIT_PCT', N'Signal wait percent of total waits', 25, 40, N'Percent');
END
GO

IF OBJECT_ID(N'dbo.PerfWaitSnapshot', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PerfWaitSnapshot
    (
        WaitSnapshotId BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        WaitType       NVARCHAR(120) NOT NULL,
        WaitingTasksCount BIGINT NOT NULL,
        WaitTimeMs     BIGINT NOT NULL,
        MaxWaitTimeMs  BIGINT NOT NULL,
        SignalWaitTimeMs BIGINT NOT NULL,
        CapturedAt     DATETIME2 NOT NULL CONSTRAINT DF_PerfWait_At DEFAULT (SYSUTCDATETIME())
    );
    CREATE INDEX IX_PerfWaitSnapshot_At ON dbo.PerfWaitSnapshot (CapturedAt DESC) INCLUDE (WaitType, WaitTimeMs);
END
GO

IF OBJECT_ID(N'dbo.CapacityForecastCache', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CapacityForecastCache
    (
        ForecastId         INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        DatabaseName       NVARCHAR(128) NOT NULL,
        CurrentSizeMB      DECIMAL(18,2) NOT NULL,
        UsedSpaceMB        DECIMAL(18,2) NOT NULL,
        AvgDailyGrowthMB   DECIMAL(18,4) NOT NULL,
        ProjectedSize30dMB DECIMAL(18,2) NULL,
        ProjectedSize90dMB DECIMAL(18,2) NULL,
        DaysUntilFull      INT NULL,
        ForecastMethod     NVARCHAR(50) NOT NULL,
        CapturedAt         DATETIME2 NOT NULL CONSTRAINT DF_CapForecast_At DEFAULT (SYSUTCDATETIME())
    );
END
GO

IF OBJECT_ID(N'dbo.CapacityPerfRunLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CapacityPerfRunLog
    (
        RunId        INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        JobName      NVARCHAR(128) NOT NULL,
        StepName     NVARCHAR(128) NOT NULL,
        StartTime    DATETIME2 NOT NULL CONSTRAINT DF_CapPerfRun_Start DEFAULT (SYSUTCDATETIME()),
        EndTime      DATETIME2 NULL,
        Status       NVARCHAR(20) NOT NULL,
        Details      NVARCHAR(MAX) NULL,
        ErrorMessage NVARCHAR(4000) NULL
    );
END
GO

PRINT '01_CapacityPerformance_Schema completed.';
GO
