/*
================================================================================
  Capacity / Performance Alerting Procedures
  Database: EmployeeLeaveDb

  AlertTypes added: Storage, VolumeSpace, Fragmentation, SlowQuery,
                    FailedJob, CapacityThreshold, WaitStats
================================================================================
*/
USE EmployeeLeaveDb;
GO

CREATE OR ALTER FUNCTION dbo.fn_Cap_GetThreshold
(
    @Code NVARCHAR(50),
    @PreferCrit BIT
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @Val DECIMAL(18,2);
    SELECT @Val = CASE WHEN @PreferCrit = 1 THEN CritValue ELSE WarnValue END
    FROM dbo.CapacityAlertThreshold
    WHERE ThresholdCode = @Code AND IsActive = 1;
    RETURN @Val;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CapPerf_Alert_LowStorage
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Warn DECIMAL(18,2) = ISNULL(dbo.fn_Cap_GetThreshold(N'STORAGE_USED_PCT', 0), 80);
    DECLARE @Crit DECIMAL(18,2) = ISNULL(dbo.fn_Cap_GetThreshold(N'STORAGE_USED_PCT', 1), 90);

    ;WITH Used AS (
        SELECT CAST(CASE WHEN SUM(df.size) = 0 THEN 0
                         ELSE SUM(FILEPROPERTY(df.name, 'SpaceUsed')) * 100.0 / SUM(df.size)
                    END AS DECIMAL(9,2)) AS UsedPct
        FROM sys.database_files df
    )
    INSERT INTO dbo.OpsAlertLog (AlertType, Severity, MessageText, MetricValue, ThresholdValue)
    SELECT N'Storage',
           CASE WHEN u.UsedPct >= @Crit THEN N'Critical' ELSE N'Warning' END,
           CONCAT(N'Database storage utilization at ', u.UsedPct, N'%'),
           u.UsedPct,
           CASE WHEN u.UsedPct >= @Crit THEN @Crit ELSE @Warn END
    FROM Used u
    WHERE u.UsedPct >= @Warn
      AND NOT EXISTS (
          SELECT 1 FROM dbo.OpsAlertLog a
          WHERE a.AlertType = N'Storage'
            AND a.IsAcknowledged = 0
            AND a.CapturedAt >= DATEADD(HOUR, -6, SYSUTCDATETIME()));
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CapPerf_Alert_VolumeSpace
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WarnFree DECIMAL(18,2) = ISNULL(dbo.fn_Cap_GetThreshold(N'VOLUME_FREE_PCT', 0), 15);
    DECLARE @CritFree DECIMAL(18,2) = ISNULL(dbo.fn_Cap_GetThreshold(N'VOLUME_FREE_PCT', 1), 10);

    INSERT INTO dbo.OpsAlertLog (AlertType, Severity, MessageText, MetricValue, ThresholdValue)
    SELECT DISTINCT
        N'VolumeSpace',
        CASE WHEN freePct <= @CritFree THEN N'Critical' ELSE N'Warning' END,
        CONCAT(N'Volume ', vs.volume_mount_point, N' free space at ', freePct, N'%'),
        freePct,
        CASE WHEN freePct <= @CritFree THEN @CritFree ELSE @WarnFree END
    FROM sys.master_files mf
    CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs
    CROSS APPLY (SELECT CAST(vs.available_bytes * 100.0 / NULLIF(vs.total_bytes, 0) AS DECIMAL(9,2)) AS freePct) x
    WHERE mf.database_id = DB_ID()
      AND freePct <= @WarnFree
      AND NOT EXISTS (
          SELECT 1 FROM dbo.OpsAlertLog a
          WHERE a.AlertType = N'VolumeSpace'
            AND a.MessageText LIKE N'Volume ' + vs.volume_mount_point + N'%'
            AND a.CapturedAt >= DATEADD(HOUR, -6, SYSUTCDATETIME()));
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CapPerf_Alert_IndexFragmentation
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Warn DECIMAL(18,2) = ISNULL(dbo.fn_Cap_GetThreshold(N'INDEX_FRAG_PCT', 0), 30);
    DECLARE @Crit DECIMAL(18,2) = ISNULL(dbo.fn_Cap_GetThreshold(N'INDEX_FRAG_PCT', 1), 50);

    INSERT INTO dbo.OpsAlertLog (AlertType, Severity, MessageText, MetricValue, ThresholdValue)
    SELECT TOP (20)
        N'Fragmentation',
        CASE WHEN ips.avg_fragmentation_in_percent >= @Crit THEN N'Critical' ELSE N'Warning' END,
        CONCAT(N'Index ', i.name, N' on ', OBJECT_SCHEMA_NAME(ips.object_id), N'.', OBJECT_NAME(ips.object_id),
               N' fragmented at ', CAST(ips.avg_fragmentation_in_percent AS DECIMAL(5,2)), N'%'),
        CAST(ips.avg_fragmentation_in_percent AS DECIMAL(18,2)),
        CASE WHEN ips.avg_fragmentation_in_percent >= @Crit THEN @Crit ELSE @Warn END
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, N'LIMITED') ips
    INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE ips.page_count >= 50
      AND i.name IS NOT NULL
      AND ips.avg_fragmentation_in_percent >= @Warn
      AND OBJECTPROPERTY(ips.object_id, 'IsMsShipped') = 0
      AND NOT EXISTS (
          SELECT 1 FROM dbo.OpsAlertLog a
          WHERE a.AlertType = N'Fragmentation'
            AND a.MessageText LIKE N'Index ' + i.name + N' on %'
            AND a.CapturedAt >= DATEADD(HOUR, -12, SYSUTCDATETIME()));
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CapPerf_Alert_LongRunningQueries
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WarnSec DECIMAL(18,2) = ISNULL(dbo.fn_Cap_GetThreshold(N'LONG_QUERY_SEC', 0), 60);
    DECLARE @CritSec DECIMAL(18,2) = ISNULL(dbo.fn_Cap_GetThreshold(N'LONG_QUERY_SEC', 1), 180);

    INSERT INTO dbo.OpsAlertLog (AlertType, Severity, MessageText, MetricValue, ThresholdValue)
    SELECT TOP (10)
        N'SlowQuery',
        CASE WHEN r.total_elapsed_time / 1000.0 >= @CritSec THEN N'Critical' ELSE N'Warning' END,
        CONCAT(N'Long-running query session ', r.session_id, N' by ', ISNULL(s.login_name, N'?'),
               N' elapsed ', r.total_elapsed_time / 1000, N's'),
        r.total_elapsed_time / 1000.0,
        CASE WHEN r.total_elapsed_time / 1000.0 >= @CritSec THEN @CritSec ELSE @WarnSec END
    FROM sys.dm_exec_requests r
    INNER JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
    WHERE r.database_id = DB_ID()
      AND r.session_id <> @@SPID
      AND r.total_elapsed_time >= (@WarnSec * 1000)
      AND NOT EXISTS (
          SELECT 1 FROM dbo.OpsAlertLog a
          WHERE a.AlertType = N'SlowQuery'
            AND a.MessageText LIKE N'Long-running query session ' + CAST(r.session_id AS NVARCHAR(20)) + N'%'
            AND a.CapturedAt >= DATEADD(HOUR, -1, SYSUTCDATETIME()));
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CapPerf_Alert_FailedAgentJobs
    @HoursBack INT = 6
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID(N'dbo.sp_Monitor_FailedAgentJobs', N'P') IS NOT NULL
    BEGIN
        EXEC dbo.sp_Monitor_FailedAgentJobs @HoursBack = @HoursBack;
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'msdb')
        RETURN;

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
            AND a.CapturedAt >= DATEADD(HOUR, -@HoursBack, SYSUTCDATETIME()));
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CapPerf_Alert_CapacityThreshold
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WarnDays DECIMAL(18,2) = ISNULL(dbo.fn_Cap_GetThreshold(N'CAPACITY_DAYS_LEFT', 0), 90);
    DECLARE @CritDays DECIMAL(18,2) = ISNULL(dbo.fn_Cap_GetThreshold(N'CAPACITY_DAYS_LEFT', 1), 30);

    DECLARE @DaysLeft INT =
        (SELECT TOP 1 DaysUntilFull FROM dbo.CapacityForecastCache ORDER BY ForecastId DESC);

    IF @DaysLeft IS NULL
    BEGIN
        EXEC dbo.sp_Cap_ForecastCapacity @LookbackDays = 90;
        SELECT TOP 1 @DaysLeft = DaysUntilFull FROM dbo.CapacityForecastCache ORDER BY ForecastId DESC;
    END

    IF @DaysLeft IS NOT NULL AND @DaysLeft <= @WarnDays
    BEGIN
        INSERT INTO dbo.OpsAlertLog (AlertType, Severity, MessageText, MetricValue, ThresholdValue)
        SELECT N'CapacityThreshold',
               CASE WHEN @DaysLeft <= @CritDays THEN N'Critical' ELSE N'Warning' END,
               CONCAT(N'Projected capacity exhaustion in ', @DaysLeft, N' days'),
               @DaysLeft,
               CASE WHEN @DaysLeft <= @CritDays THEN @CritDays ELSE @WarnDays END
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.OpsAlertLog a
            WHERE a.AlertType = N'CapacityThreshold'
              AND a.IsAcknowledged = 0
              AND a.CapturedAt >= DATEADD(HOUR, -12, SYSUTCDATETIME()));
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CapPerf_RunAllAlerts
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunId INT;
    EXEC dbo.sp_CapPerf_LogStart N'ELM_CapPerf_AlertScan', N'RunAllAlerts', @RunId OUTPUT;

    BEGIN TRY
        EXEC dbo.sp_CapPerf_Alert_LowStorage;
        EXEC dbo.sp_CapPerf_Alert_VolumeSpace;
        EXEC dbo.sp_CapPerf_Alert_IndexFragmentation;
        EXEC dbo.sp_CapPerf_Alert_LongRunningQueries;
        EXEC dbo.sp_CapPerf_Alert_FailedAgentJobs @HoursBack = 6;
        EXEC dbo.sp_CapPerf_Alert_CapacityThreshold;

        DECLARE @Open INT = (SELECT COUNT(*) FROM dbo.OpsAlertLog WHERE IsAcknowledged = 0 AND CapturedAt >= DATEADD(HOUR, -6, SYSUTCDATETIME()));
        DECLARE @Details NVARCHAR(200) = CONCAT(N'Alert scan complete. Recent open alerts=', @Open);
        EXEC dbo.sp_CapPerf_LogEnd @RunId, N'Success', @Details;
    END TRY
    BEGIN CATCH
        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        EXEC dbo.sp_CapPerf_LogEnd @RunId, N'Failed', NULL, @Err;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CapPerf_AcknowledgeAlert
    @AlertId INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.OpsAlertLog
    SET IsAcknowledged = 1
    WHERE AlertId = @AlertId AND IsAcknowledged = 0;

    IF @@ROWCOUNT = 0
        THROW 50020, 'Alert not found or already acknowledged.', 1;

    SELECT * FROM dbo.OpsAlertLog WHERE AlertId = @AlertId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CapPerf_UpdateThreshold
    @ThresholdCode NVARCHAR(50),
    @WarnValue DECIMAL(18,2),
    @CritValue DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.CapacityAlertThreshold
    SET WarnValue = @WarnValue,
        CritValue = @CritValue,
        ModifiedAt = SYSUTCDATETIME()
    WHERE ThresholdCode = @ThresholdCode AND IsActive = 1;

    IF @@ROWCOUNT = 0
        THROW 50021, 'Threshold code not found.', 1;

    SELECT * FROM dbo.CapacityAlertThreshold WHERE ThresholdCode = @ThresholdCode;
END
GO

PRINT '04_Alerting_Procedures completed.';
GO
