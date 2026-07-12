/*
================================================================================
  Performance / Maintenance Report Procedures
  Database: EmployeeLeaveDb
================================================================================
*/
USE EmployeeLeaveDb;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_MonthlyDatabaseGrowth
    @MonthsBack INT = 12
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH SizeSnapshots AS (
        SELECT
            DATEFROMPARTS(YEAR(CapturedAt), MONTH(CapturedAt), 1) AS MonthStart,
            MetricName,
            MetricValue,
            ROW_NUMBER() OVER (
                PARTITION BY DATEFROMPARTS(YEAR(CapturedAt), MONTH(CapturedAt), 1), MetricName
                ORDER BY CapturedAt DESC) AS rn
        FROM dbo.DatabaseMetricSnapshot
        WHERE MetricCategory = N'Size'
          AND CapturedAt >= DATEADD(MONTH, -@MonthsBack, SYSUTCDATETIME())
    )
    SELECT
        Year = YEAR(MonthStart),
        Month = MONTH(MonthStart),
        MonthName = DATENAME(MONTH, MonthStart),
        TotalSizeMB = MAX(CASE WHEN MetricName = N'TotalSizeMB' THEN MetricValue END),
        UsedSpaceMB = MAX(CASE WHEN MetricName = N'UsedSpaceMB' THEN MetricValue END),
        UsedPercent = MAX(CASE WHEN MetricName = N'UsedPercent' THEN MetricValue END)
    FROM SizeSnapshots
    WHERE rn = 1
    GROUP BY MonthStart
    ORDER BY MonthStart;

    /* Fallback live snapshot when history is empty */
    IF NOT EXISTS (
        SELECT 1 FROM dbo.DatabaseMetricSnapshot
        WHERE MetricCategory = N'Size'
          AND CapturedAt >= DATEADD(MONTH, -@MonthsBack, SYSUTCDATETIME()))
    BEGIN
        SELECT
            YEAR(SYSUTCDATETIME()) AS Year,
            MONTH(SYSUTCDATETIME()) AS Month,
            DATENAME(MONTH, SYSUTCDATETIME()) AS MonthName,
            CAST(SUM(size) * 8.0 / 1024 AS DECIMAL(18,2)) AS TotalSizeMB,
            CAST(SUM(FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(18,2)) AS UsedSpaceMB,
            CAST(
                CASE WHEN SUM(size) = 0 THEN 0
                     ELSE SUM(FILEPROPERTY(name, 'SpaceUsed')) * 100.0 / SUM(size)
                END AS DECIMAL(5,2)) AS UsedPercent
        FROM sys.database_files;
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_IndexHealth
    @MinPageCount INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        OBJECT_SCHEMA_NAME(ips.object_id) AS SchemaName,
        OBJECT_NAME(ips.object_id) AS TableName,
        i.name AS IndexName,
        ips.index_type_desc AS IndexType,
        CAST(ips.avg_fragmentation_in_percent AS DECIMAL(5,2)) AS FragmentationPercent,
        ips.page_count AS PageCount,
        CASE
            WHEN ips.avg_fragmentation_in_percent >= 30 THEN N'Rebuild'
            WHEN ips.avg_fragmentation_in_percent >= 10 THEN N'Reorganize'
            ELSE N'Healthy'
        END AS HealthStatus
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, N'LIMITED') ips
    INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE ips.page_count >= @MinPageCount
      AND i.name IS NOT NULL
    ORDER BY ips.avg_fragmentation_in_percent DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_QueryPerformance
    @TopN INT = 25
AS
BEGIN
    SET NOCOUNT ON;

    /* Prefer currently running / recent requests; also surface plan-cache stats when available */
    SELECT TOP (@TopN)
        qs.execution_count AS ExecutionCount,
        qs.total_elapsed_time / 1000 AS TotalElapsedMs,
        qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000 AS AvgElapsedMs,
        qs.total_worker_time / 1000 AS TotalCpuMs,
        qs.total_logical_reads AS TotalLogicalReads,
        qs.last_execution_time AS LastExecutionTime,
        SUBSTRING(st.text, (qs.statement_start_offset / 2) + 1,
            ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)
              ELSE qs.statement_end_offset END - qs.statement_start_offset) / 2) + 1) AS QueryText
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
    WHERE DB_NAME(st.dbid) = DB_NAME() OR st.dbid IS NULL
    ORDER BY qs.total_elapsed_time DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_ArchiveSummary
    @DaysBack INT = 90
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        EntityName,
        COUNT(*) AS RunCount,
        SUM(CASE WHEN Status = N'Success' THEN 1 ELSE 0 END) AS SuccessCount,
        SUM(CASE WHEN Status = N'Failed' THEN 1 ELSE 0 END) AS FailedCount,
        SUM(ISNULL(RowsArchived, 0)) AS TotalRowsArchived,
        MIN(StartTime) AS FirstRun,
        MAX(StartTime) AS LastRun
    FROM dbo.ArchiveRunLog
    WHERE StartTime >= DATEADD(DAY, -@DaysBack, SYSUTCDATETIME())
    GROUP BY EntityName
    ORDER BY EntityName;

    SELECT
        EntityName,
        LiveRows,
        ArchivedRows,
        CAST(CASE WHEN LiveRows + ArchivedRows = 0 THEN 0
                  ELSE ArchivedRows * 100.0 / (LiveRows + ArchivedRows)
             END AS DECIMAL(5,2)) AS ArchivedPercent
    FROM (
        SELECT N'LeaveRequests' AS EntityName,
               (SELECT COUNT(*) FROM dbo.LeaveRequests) AS LiveRows,
               (SELECT COUNT(*) FROM dbo.LeaveRequestsArchive) AS ArchivedRows
        UNION ALL
        SELECT N'Notifications',
               (SELECT COUNT(*) FROM dbo.Notifications),
               (SELECT COUNT(*) FROM dbo.NotificationsArchive)
        UNION ALL
        SELECT N'AuditLogs',
               (SELECT COUNT(*) FROM dbo.AuditLogs),
               (SELECT COUNT(*) FROM dbo.AuditLogsArchive)
        UNION ALL
        SELECT N'LeaveBalances',
               (SELECT COUNT(*) FROM dbo.LeaveBalances),
               (SELECT COUNT(*) FROM dbo.LeaveBalancesArchive)
    ) s;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_MaintenanceExecution
    @DaysBack INT = 90
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        JobName,
        StepName,
        COUNT(*) AS RunCount,
        SUM(CASE WHEN Status = N'Success' THEN 1 ELSE 0 END) AS SuccessCount,
        SUM(CASE WHEN Status = N'Failed' THEN 1 ELSE 0 END) AS FailedCount,
        MIN(StartTime) AS FirstRun,
        MAX(StartTime) AS LastRun,
        AVG(DATEDIFF(SECOND, StartTime, ISNULL(EndTime, StartTime))) AS AvgDurationSeconds
    FROM dbo.MaintenanceRunLog
    WHERE StartTime >= DATEADD(DAY, -@DaysBack, SYSUTCDATETIME())
    GROUP BY JobName, StepName
    ORDER BY JobName, StepName;

    SELECT TOP (100)
        MaintenanceRunId, JobName, StepName, StartTime, EndTime, Status, Details, ErrorMessage
    FROM dbo.MaintenanceRunLog
    WHERE StartTime >= DATEADD(DAY, -@DaysBack, SYSUTCDATETIME())
    ORDER BY MaintenanceRunId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_GetRetentionConfig
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ConfigId, EntityName, RetentionDays, IsEnabled, Description, LastModifiedUtc
    FROM dbo.ArchiveRetentionConfig
    ORDER BY EntityName;
END
GO

PRINT '05_Report_Procedures.sql completed.';
GO
