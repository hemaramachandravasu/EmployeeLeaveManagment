/*
================================================================================
  Capacity / Performance Reports + Unified Dashboard
  Database: EmployeeLeaveDb
================================================================================
*/
USE EmployeeLeaveDb;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_CapacityPlanningSummary
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TotalMB DECIMAL(18,2), @UsedMB DECIMAL(18,2), @UsedPct DECIMAL(5,2);
    SELECT
        @TotalMB = CAST(SUM(size) * 8.0 / 1024 AS DECIMAL(18,2)),
        @UsedMB = CAST(SUM(FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(18,2))
    FROM sys.database_files;
    SET @UsedPct = CASE WHEN @TotalMB = 0 THEN 0 ELSE CAST(@UsedMB * 100.0 / @TotalMB AS DECIMAL(5,2)) END;

    SELECT TOP 1
        DB_NAME() AS DatabaseName,
        @TotalMB AS CurrentSizeMB,
        @UsedMB AS UsedSpaceMB,
        @UsedPct AS UsedPercent,
        f.AvgDailyGrowthMB,
        f.ProjectedSize30dMB,
        f.ProjectedSize90dMB,
        f.DaysUntilFull,
        f.ForecastMethod,
        f.CapturedAt AS ForecastCapturedAt,
        (SELECT COUNT(*) FROM dbo.OpsAlertLog
         WHERE AlertType IN (N'Storage', N'VolumeSpace', N'CapacityThreshold')
           AND IsAcknowledged = 0) AS OpenCapacityAlerts,
        SYSUTCDATETIME() AS CapturedAtUtc
    FROM dbo.CapacityForecastCache f
    ORDER BY f.ForecastId DESC;

    IF NOT EXISTS (SELECT 1 FROM dbo.CapacityForecastCache)
    BEGIN
        SELECT
            DB_NAME() AS DatabaseName,
            @TotalMB AS CurrentSizeMB,
            @UsedMB AS UsedSpaceMB,
            @UsedPct AS UsedPercent,
            CAST(NULL AS DECIMAL(18,4)) AS AvgDailyGrowthMB,
            CAST(NULL AS DECIMAL(18,2)) AS ProjectedSize30dMB,
            CAST(NULL AS DECIMAL(18,2)) AS ProjectedSize90dMB,
            CAST(NULL AS INT) AS DaysUntilFull,
            CAST(N'NotComputed' AS NVARCHAR(50)) AS ForecastMethod,
            CAST(NULL AS DATETIME2) AS ForecastCapturedAt,
            (SELECT COUNT(*) FROM dbo.OpsAlertLog
             WHERE AlertType IN (N'Storage', N'VolumeSpace', N'CapacityThreshold')
               AND IsAcknowledged = 0) AS OpenCapacityAlerts,
            SYSUTCDATETIME() AS CapturedAtUtc;
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_SqlPerformanceAnalysis
    @TopN INT = 15
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Perf_SlowQueryStatistics @TopN = @TopN, @MinElapsedMs = 20;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_StorageUtilizationDetail
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Cap_StorageUtilization;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_ResourceConsumption
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Perf_ResourceConsumptionSummary;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_CapPerfAlertHistory
    @DaysBack INT = 30,
    @UnacknowledgedOnly BIT = 0,
    @AlertType NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        a.AlertId,
        a.AlertType,
        a.Severity,
        a.MessageText,
        a.MetricValue,
        a.ThresholdValue,
        a.CapturedAt,
        a.IsAcknowledged
    FROM dbo.OpsAlertLog a
    WHERE a.CapturedAt >= DATEADD(DAY, -@DaysBack, SYSUTCDATETIME())
      AND (@UnacknowledgedOnly = 0 OR a.IsAcknowledged = 0)
      AND (@AlertType IS NULL OR a.AlertType = @AlertType)
      AND a.AlertType IN (
          N'Storage', N'VolumeSpace', N'Fragmentation', N'SlowQuery',
          N'FailedJob', N'CapacityThreshold', N'WaitStats', N'LongTx', N'BackupLag')
    ORDER BY a.CapturedAt DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CapPerf_Dashboard
AS
BEGIN
    SET NOCOUNT ON;

    /* RS1: Capacity summary */
    EXEC dbo.sp_Report_CapacityPlanningSummary;

    /* RS2: Resource consumption */
    EXEC dbo.sp_Perf_ResourceConsumptionSummary;

    /* RS3: Top waits */
    EXEC dbo.sp_Perf_WaitStatistics @TopN = 10, @PersistSnapshot = 0;

    /* RS4: Open alerts count by type */
    SELECT AlertType, Severity, COUNT(*) AS AlertCount
    FROM dbo.OpsAlertLog
    WHERE IsAcknowledged = 0
      AND CapturedAt >= DATEADD(DAY, -7, SYSUTCDATETIME())
    GROUP BY AlertType, Severity
    ORDER BY AlertCount DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CapPerf_ArchiveHistoricalData
    @RetainMetricDays INT = 180,
    @RetainWaitDays INT = 90,
    @RetainForecastDays INT = 365,
    @RetainAlertDays INT = 120
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunId INT;
    EXEC dbo.sp_CapPerf_LogStart N'ELM_CapPerf_ArchiveHistory', N'Archive', @RunId OUTPUT;

    BEGIN TRY
        DELETE FROM dbo.DatabaseMetricSnapshot
        WHERE CapturedAt < DATEADD(DAY, -@RetainMetricDays, SYSUTCDATETIME());
        DECLARE @M INT = @@ROWCOUNT;

        DELETE FROM dbo.PerfWaitSnapshot
        WHERE CapturedAt < DATEADD(DAY, -@RetainWaitDays, SYSUTCDATETIME());
        DECLARE @W INT = @@ROWCOUNT;

        DELETE FROM dbo.CapacityForecastCache
        WHERE CapturedAt < DATEADD(DAY, -@RetainForecastDays, SYSUTCDATETIME())
          AND ForecastId NOT IN (SELECT TOP 1 ForecastId FROM dbo.CapacityForecastCache ORDER BY ForecastId DESC);
        DECLARE @F INT = @@ROWCOUNT;

        DELETE FROM dbo.OpsAlertLog
        WHERE IsAcknowledged = 1
          AND CapturedAt < DATEADD(DAY, -@RetainAlertDays, SYSUTCDATETIME());
        DECLARE @A INT = @@ROWCOUNT;

        DECLARE @Details NVARCHAR(300) =
            CONCAT(N'Deleted metrics=', @M, N' waits=', @W, N' forecasts=', @F, N' alerts=', @A);
        EXEC dbo.sp_CapPerf_LogEnd @RunId, N'Success', @Details;
    END TRY
    BEGIN CATCH
        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        EXEC dbo.sp_CapPerf_LogEnd @RunId, N'Failed', NULL, @Err;
        THROW;
    END CATCH
END
GO

PRINT '05_Report_Procedures completed.';
GO
