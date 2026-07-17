/*
  Operational monitoring for backups, Agent jobs, storage, long transactions, access snapshot
*/
USE EmployeeLeaveDb;
GO

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_BackupStatus
    @DatabaseName SYSNAME = N'EmployeeLeaveDb',
    @MaxFullAgeHours INT = 36,
    @MaxLogAgeMinutes INT = 60
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LastFull DATETIME2, @LastDiff DATETIME2, @LastLog DATETIME2;
    DECLARE @LastFullStatus NVARCHAR(20), @LastLogStatus NVARCHAR(20);

    SELECT TOP (1) @LastFull = EndTime, @LastFullStatus = Status
    FROM dbo.BackupRunLog
    WHERE DatabaseName = @DatabaseName AND BackupType = N'Full' AND Status IN (N'Success', N'Verified')
    ORDER BY BackupRunId DESC;

    SELECT TOP (1) @LastDiff = EndTime
    FROM dbo.BackupRunLog
    WHERE DatabaseName = @DatabaseName AND BackupType = N'Differential' AND Status IN (N'Success', N'Verified')
    ORDER BY BackupRunId DESC;

    SELECT TOP (1) @LastLog = EndTime, @LastLogStatus = Status
    FROM dbo.BackupRunLog
    WHERE DatabaseName = @DatabaseName AND BackupType = N'Log' AND Status IN (N'Success', N'Verified')
    ORDER BY BackupRunId DESC;

    SELECT
        @DatabaseName AS DatabaseName,
        (SELECT recovery_model_desc FROM sys.databases WHERE name = @DatabaseName) AS RecoveryModel,
        @LastFull AS LastFullBackupUtc,
        @LastFullStatus AS LastFullStatus,
        @LastDiff AS LastDiffBackupUtc,
        @LastLog AS LastLogBackupUtc,
        @LastLogStatus AS LastLogStatus,
        DATEDIFF(HOUR, @LastFull, SYSUTCDATETIME()) AS FullBackupAgeHours,
        DATEDIFF(MINUTE, @LastLog, SYSUTCDATETIME()) AS LogBackupAgeMinutes,
        CASE
            WHEN @LastFull IS NULL THEN N'Critical'
            WHEN DATEDIFF(HOUR, @LastFull, SYSUTCDATETIME()) > @MaxFullAgeHours THEN N'Warning'
            ELSE N'Healthy'
        END AS FullBackupHealth,
        CASE
            WHEN (SELECT recovery_model_desc FROM sys.databases WHERE name = @DatabaseName) <> N'FULL' THEN N'N/A'
            WHEN @LastLog IS NULL THEN N'Critical'
            WHEN DATEDIFF(MINUTE, @LastLog, SYSUTCDATETIME()) > @MaxLogAgeMinutes THEN N'Warning'
            ELSE N'Healthy'
        END AS LogBackupHealth,
        (SELECT COUNT(*) FROM dbo.BackupRunLog
         WHERE DatabaseName = @DatabaseName AND Status = N'Failed'
           AND StartTime >= DATEADD(DAY, -7, SYSUTCDATETIME())) AS FailedBackupsLast7Days;

    -- Raise ops alerts when unhealthy
    IF @LastFull IS NULL OR DATEDIFF(HOUR, ISNULL(@LastFull, '2000-01-01'), SYSUTCDATETIME()) > @MaxFullAgeHours
        INSERT INTO dbo.OpsAlertLog (AlertType, Severity, MessageText, MetricValue, ThresholdValue)
        VALUES (N'BackupLag', N'Critical',
                N'Full backup missing or older than threshold for ' + @DatabaseName,
                CAST(DATEDIFF(HOUR, ISNULL(@LastFull, '2000-01-01'), SYSUTCDATETIME()) AS DECIMAL(18,2)),
                @MaxFullAgeHours);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_FailedAgentJobs
    @HoursBack INT = 24
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        j.name AS JobName,
        h.step_name AS StepName,
        h.run_date AS RunDate,
        h.run_time AS RunTime,
        h.run_status AS RunStatus,
        CASE h.run_status
            WHEN 0 THEN N'Failed'
            WHEN 1 THEN N'Succeeded'
            WHEN 2 THEN N'Retry'
            WHEN 3 THEN N'Canceled'
            WHEN 4 THEN N'In Progress'
            ELSE CAST(h.run_status AS NVARCHAR(20))
        END AS StatusName,
        h.message AS MessageText,
        msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunDateTime
    FROM msdb.dbo.sysjobhistory h
    INNER JOIN msdb.dbo.sysjobs j ON j.job_id = h.job_id
    WHERE h.run_status = 0
      AND h.step_id > 0
      AND msdb.dbo.agent_datetime(h.run_date, h.run_time) >= DATEADD(HOUR, -@HoursBack, SYSUTCDATETIME())
      AND j.name LIKE N'ELM_%'
    ORDER BY RunDateTime DESC;

    INSERT INTO dbo.OpsAlertLog (AlertType, Severity, MessageText, MetricValue, ThresholdValue)
    SELECT N'FailedJob', N'Warning',
           N'Failed Agent job step: ' + j.name + N' / ' + h.step_name,
           1, 0
    FROM msdb.dbo.sysjobhistory h
    INNER JOIN msdb.dbo.sysjobs j ON j.job_id = h.job_id
    WHERE h.run_status = 0
      AND h.step_id > 0
      AND msdb.dbo.agent_datetime(h.run_date, h.run_time) >= DATEADD(HOUR, -@HoursBack, SYSUTCDATETIME())
      AND j.name LIKE N'ELM_%'
      AND NOT EXISTS (
          SELECT 1 FROM dbo.OpsAlertLog a
          WHERE a.AlertType = N'FailedJob'
            AND a.MessageText = N'Failed Agent job step: ' + j.name + N' / ' + h.step_name
            AND a.CapturedAt >= DATEADD(HOUR, -@HoursBack, SYSUTCDATETIME())
      );
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_StorageCapacityAlerts
    @WarnUsedPercent DECIMAL(9,2) = 80,
    @CritUsedPercent DECIMAL(9,2) = 90
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Size AS
    (
        SELECT
            DB_NAME() AS DatabaseName,
            CAST(SUM(size) * 8.0 / 1024 AS DECIMAL(18,2)) AS TotalSizeMB,
            CAST(SUM(CASE WHEN type_desc = N'ROWS' THEN size ELSE 0 END) * 8.0 / 1024 AS DECIMAL(18,2)) AS DataSizeMB,
            CAST(SUM(CASE WHEN type_desc = N'LOG' THEN size ELSE 0 END) * 8.0 / 1024 AS DECIMAL(18,2)) AS LogSizeMB
        FROM sys.database_files
    ),
    Used AS
    (
        SELECT
            CAST(SUM(reserved_page_count) * 8.0 / 1024 AS DECIMAL(18,2)) AS UsedSpaceMB
        FROM sys.dm_db_partition_stats
    )
    SELECT
        s.DatabaseName,
        s.TotalSizeMB,
        s.DataSizeMB,
        s.LogSizeMB,
        u.UsedSpaceMB,
        CAST(s.TotalSizeMB - u.UsedSpaceMB AS DECIMAL(18,2)) AS FreeSpaceMB,
        CAST(CASE WHEN s.TotalSizeMB = 0 THEN 0 ELSE (u.UsedSpaceMB * 100.0 / s.TotalSizeMB) END AS DECIMAL(9,2)) AS UsedPercent,
        CASE
            WHEN CASE WHEN s.TotalSizeMB = 0 THEN 0 ELSE (u.UsedSpaceMB * 100.0 / s.TotalSizeMB) END >= @CritUsedPercent THEN N'Critical'
            WHEN CASE WHEN s.TotalSizeMB = 0 THEN 0 ELSE (u.UsedSpaceMB * 100.0 / s.TotalSizeMB) END >= @WarnUsedPercent THEN N'Warning'
            ELSE N'Healthy'
        END AS StorageHealth,
        @WarnUsedPercent AS WarnThresholdPercent,
        @CritUsedPercent AS CritThresholdPercent
    FROM Size s
    CROSS JOIN Used u;

    INSERT INTO dbo.OpsAlertLog (AlertType, Severity, MessageText, MetricValue, ThresholdValue)
    SELECT N'Storage',
           CASE WHEN usedPct >= @CritUsedPercent THEN N'Critical' ELSE N'Warning' END,
           N'Database storage utilization at ' + CAST(usedPct AS NVARCHAR(20)) + N'%',
           usedPct,
           CASE WHEN usedPct >= @CritUsedPercent THEN @CritUsedPercent ELSE @WarnUsedPercent END
    FROM (
        SELECT CAST(CASE WHEN SUM(df.size) = 0 THEN 0
                         ELSE (SELECT SUM(reserved_page_count) FROM sys.dm_db_partition_stats) * 100.0 / SUM(df.size)
                    END AS DECIMAL(9,2)) AS usedPct
        FROM sys.database_files df
    ) x
    WHERE usedPct >= @WarnUsedPercent;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_LongRunningTransactions
    @MinDurationSeconds INT = 60
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        at.transaction_id AS TransactionId,
        at.name AS TransactionName,
        at.transaction_begin_time AS BeginTime,
        DATEDIFF(SECOND, at.transaction_begin_time, SYSUTCDATETIME()) AS DurationSeconds,
        at.transaction_type AS TransactionType,
        at.transaction_state AS TransactionState,
        s.session_id AS SessionId,
        s.login_name AS LoginName,
        s.host_name AS HostName,
        s.program_name AS ProgramName,
        DB_NAME(dt.database_id) AS DatabaseName,
        LEFT(REPLACE(REPLACE(t.text, CHAR(13), ' '), CHAR(10), ' '), 400) AS QueryText
    FROM sys.dm_tran_active_transactions at
    INNER JOIN sys.dm_tran_session_transactions st ON st.transaction_id = at.transaction_id
    INNER JOIN sys.dm_exec_sessions s ON s.session_id = st.session_id
    LEFT JOIN sys.dm_tran_database_transactions dt ON dt.transaction_id = at.transaction_id
    OUTER APPLY (
        SELECT TOP (1) r.session_id, r.sql_handle
        FROM sys.dm_exec_requests r
        WHERE r.session_id = s.session_id
    ) req
    OUTER APPLY sys.dm_exec_sql_text(req.sql_handle) t
    WHERE DATEDIFF(SECOND, at.transaction_begin_time, SYSUTCDATETIME()) >= @MinDurationSeconds
      AND (dt.database_id IS NULL OR dt.database_id = DB_ID())
    ORDER BY DurationSeconds DESC;

    INSERT INTO dbo.OpsAlertLog (AlertType, Severity, MessageText, MetricValue, ThresholdValue)
    SELECT TOP (10)
        N'LongTx', N'Warning',
        N'Long-running transaction by ' + ISNULL(s.login_name, N'?') + N' session ' + CAST(s.session_id AS NVARCHAR(20)),
        DATEDIFF(SECOND, at.transaction_begin_time, SYSUTCDATETIME()),
        @MinDurationSeconds
    FROM sys.dm_tran_active_transactions at
    INNER JOIN sys.dm_tran_session_transactions st ON st.transaction_id = at.transaction_id
    INNER JOIN sys.dm_exec_sessions s ON s.session_id = st.session_id
    WHERE DATEDIFF(SECOND, at.transaction_begin_time, SYSUTCDATETIME()) >= @MinDurationSeconds;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_CaptureAccessSnapshot
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.DbAccessAuditLog (LoginName, HostName, ProgramName, DatabaseName, SessionId, Status, LoginTime, LastRequestEndTime)
    SELECT
        s.login_name,
        s.host_name,
        s.program_name,
        DB_NAME(s.database_id),
        s.session_id,
        s.status,
        s.login_time,
        s.last_request_end_time
    FROM sys.dm_exec_sessions s
    WHERE s.is_user_process = 1
      AND (s.database_id = DB_ID() OR s.database_id = 0);

    SELECT @@ROWCOUNT AS RowsCaptured, SYSUTCDATETIME() AS CapturedAt;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_OpsDashboard
    @DatabaseName SYSNAME = N'EmployeeLeaveDb'
AS
BEGIN
    SET NOCOUNT ON;

    -- 1) Backup status summary
    EXEC dbo.sp_Monitor_BackupStatus @DatabaseName = @DatabaseName;

    -- 2) Recent alerts
    SELECT TOP (20)
        AlertId, AlertType, Severity, MessageText, MetricValue, ThresholdValue, CapturedAt, IsAcknowledged
    FROM dbo.OpsAlertLog
    ORDER BY AlertId DESC;

    -- 3) Storage
    EXEC dbo.sp_Monitor_StorageCapacityAlerts;
END
GO

PRINT 'Ops monitoring procedures created.';
GO
