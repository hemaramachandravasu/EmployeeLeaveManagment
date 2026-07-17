/*
  Reporting procedures for Backup / DR / Security ops (API + export)
*/
USE EmployeeLeaveDb;
GO

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_BackupHistory
    @DatabaseName SYSNAME = N'EmployeeLeaveDb',
    @DaysBack INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        BackupRunId, DatabaseName, BackupType, BackupPath, StartTime, EndTime,
        Status, BackupSizeMB, Verified, DurationSeconds, ErrorMessage
    FROM dbo.BackupRunLog
    WHERE DatabaseName = @DatabaseName
      AND StartTime >= DATEADD(DAY, -@DaysBack, SYSUTCDATETIME())
    ORDER BY BackupRunId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_RecoveryValidation
    @DaysBack INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ValidationId, DatabaseName, ValidationType, BackupPath, TargetPointInTime,
        StartTime, EndTime, Status, Details, ErrorMessage
    FROM dbo.RecoveryValidationLog
    WHERE StartTime >= DATEADD(DAY, -@DaysBack, SYSUTCDATETIME())
    ORDER BY ValidationId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_SecurityAuditSummary
    @HoursBack INT = 24
AS
BEGIN
    SET NOCOUNT ON;

    -- Session access snapshot (recent captures)
    SELECT
        LoginName,
        COUNT(*) AS SessionSightings,
        COUNT(DISTINCT HostName) AS DistinctHosts,
        COUNT(DISTINCT ProgramName) AS DistinctPrograms,
        MIN(CapturedAt) AS FirstSeen,
        MAX(CapturedAt) AS LastSeen
    FROM dbo.DbAccessAuditLog
    WHERE CapturedAt >= DATEADD(HOUR, -@HoursBack, SYSUTCDATETIME())
    GROUP BY LoginName
    ORDER BY SessionSightings DESC;

    -- Database roles membership summary
    SELECT
        r.name AS RoleName,
        COUNT(rm.member_principal_id) AS MemberCount
    FROM sys.database_principals r
    LEFT JOIN sys.database_role_members rm ON rm.role_principal_id = r.principal_id
    WHERE r.type = 'R' AND r.name LIKE N'db_elm_%'
    GROUP BY r.name
    ORDER BY r.name;

    -- Masked columns count
    SELECT
        OBJECT_SCHEMA_NAME(c.object_id) AS SchemaName,
        OBJECT_NAME(c.object_id) AS TableName,
        c.name AS ColumnName,
        c.is_masked AS IsMasked
    FROM sys.columns c
    WHERE c.is_masked = 1
    ORDER BY SchemaName, TableName, ColumnName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_DatabaseHealthStatus
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        DB_NAME() AS DatabaseName,
        (SELECT recovery_model_desc FROM sys.databases WHERE name = DB_NAME()) AS RecoveryModel,
        (SELECT state_desc FROM sys.databases WHERE name = DB_NAME()) AS StateDesc,
        CAST(SUM(size) * 8.0 / 1024 AS DECIMAL(18,2)) AS TotalSizeMB,
        (SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE is_user_process = 1 AND database_id = DB_ID()) AS ActiveUserSessions,
        (SELECT COUNT(*) FROM dbo.BackupRunLog WHERE Status = N'Failed' AND StartTime >= DATEADD(DAY, -1, SYSUTCDATETIME())) AS FailedBackupsLast24h,
        (SELECT COUNT(*) FROM dbo.OpsAlertLog WHERE Severity = N'Critical' AND CapturedAt >= DATEADD(DAY, -1, SYSUTCDATETIME()) AND IsAcknowledged = 0) AS OpenCriticalAlerts,
        SYSUTCDATETIME() AS CapturedAtUtc
    FROM sys.database_files;

    -- Long-running requests snapshot
    SELECT TOP (10)
        r.session_id AS SessionId,
        s.login_name AS LoginName,
        r.status AS Status,
        r.command AS Command,
        r.total_elapsed_time AS ElapsedMs,
        LEFT(REPLACE(REPLACE(t.text, CHAR(13), ' '), CHAR(10), ' '), 300) AS QueryText
    FROM sys.dm_exec_requests r
    INNER JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id
    OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t
    WHERE r.session_id <> @@SPID
      AND r.database_id = DB_ID()
    ORDER BY r.total_elapsed_time DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_JobExecutionHistory
    @HoursBack INT = 72,
    @JobNamePrefix NVARCHAR(50) = N'ELM_'
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        j.name AS JobName,
        h.step_id AS StepId,
        h.step_name AS StepName,
        msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunDateTime,
        CASE h.run_status
            WHEN 0 THEN N'Failed'
            WHEN 1 THEN N'Succeeded'
            WHEN 2 THEN N'Retry'
            WHEN 3 THEN N'Canceled'
            WHEN 4 THEN N'In Progress'
            ELSE CAST(h.run_status AS NVARCHAR(20))
        END AS StatusName,
        h.run_duration AS RunDuration,
        LEFT(h.message, 500) AS MessageText
    FROM msdb.dbo.sysjobhistory h
    INNER JOIN msdb.dbo.sysjobs j ON j.job_id = h.job_id
    WHERE j.name LIKE @JobNamePrefix + N'%'
      AND h.step_id > 0
      AND msdb.dbo.agent_datetime(h.run_date, h.run_time) >= DATEADD(HOUR, -@HoursBack, SYSUTCDATETIME())
    ORDER BY RunDateTime DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_OpsAlerts
    @DaysBack INT = 7,
    @UnacknowledgedOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT AlertId, AlertType, Severity, MessageText, MetricValue, ThresholdValue, CapturedAt, IsAcknowledged
    FROM dbo.OpsAlertLog
    WHERE CapturedAt >= DATEADD(DAY, -@DaysBack, SYSUTCDATETIME())
      AND (@UnacknowledgedOnly = 0 OR IsAcknowledged = 0)
    ORDER BY AlertId DESC;
END
GO

PRINT 'Ops report procedures created.';
GO
