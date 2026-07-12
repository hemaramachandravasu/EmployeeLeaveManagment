/*
================================================================================
  Database Performance Monitoring Procedures
  Database: EmployeeLeaveDb
================================================================================
*/
USE EmployeeLeaveDb;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_SlowRunningQueries
    @TopN INT = 20,
    @MinElapsedMs INT = 1000
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@TopN)
        r.session_id AS SessionId,
        r.status AS RequestStatus,
        r.command AS CommandType,
        DB_NAME(r.database_id) AS DatabaseName,
        r.cpu_time AS CpuTimeMs,
        r.total_elapsed_time AS ElapsedMs,
        r.reads AS LogicalReads,
        r.writes AS Writes,
        r.wait_type AS WaitType,
        r.wait_time AS WaitTimeMs,
        r.blocking_session_id AS BlockingSessionId,
        SUBSTRING(t.text, (r.statement_start_offset / 2) + 1,
            ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(t.text)
              ELSE r.statement_end_offset END - r.statement_start_offset) / 2) + 1) AS RunningQuery
    FROM sys.dm_exec_requests r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
    WHERE r.session_id <> @@SPID
      AND r.total_elapsed_time >= @MinElapsedMs
    ORDER BY r.total_elapsed_time DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_DatabaseGrowth
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        DB_NAME() AS DatabaseName,
        CAST(SUM(size) * 8.0 / 1024 AS DECIMAL(18,2)) AS TotalSizeMB,
        CAST(SUM(CASE WHEN type_desc = N'ROWS' THEN size ELSE 0 END) * 8.0 / 1024 AS DECIMAL(18,2)) AS DataSizeMB,
        CAST(SUM(CASE WHEN type_desc = N'LOG' THEN size ELSE 0 END) * 8.0 / 1024 AS DECIMAL(18,2)) AS LogSizeMB,
        CAST(SUM(FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(18,2)) AS UsedSpaceMB,
        CAST((SUM(size) - SUM(FILEPROPERTY(name, 'SpaceUsed'))) * 8.0 / 1024 AS DECIMAL(18,2)) AS FreeSpaceMB,
        CAST(
            CASE WHEN SUM(size) = 0 THEN 0
                 ELSE SUM(FILEPROPERTY(name, 'SpaceUsed')) * 100.0 / SUM(size)
            END AS DECIMAL(5,2)) AS UsedPercent
    FROM sys.database_files;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_TableGrowth
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        SCHEMA_NAME(t.schema_id) AS SchemaName,
        t.name AS TableName,
        SUM(p.rows) AS RowCounts,
        CAST(SUM(a.total_pages) * 8.0 / 1024 AS DECIMAL(18,2)) AS TotalSpaceMB,
        CAST(SUM(a.used_pages) * 8.0 / 1024 AS DECIMAL(18,2)) AS UsedSpaceMB,
        CAST(SUM(a.data_pages) * 8.0 / 1024 AS DECIMAL(18,2)) AS DataSpaceMB
    FROM sys.tables t
    INNER JOIN sys.indexes i ON t.object_id = i.object_id
    INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
    INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
    WHERE t.is_ms_shipped = 0
      AND i.index_id <= 1
    GROUP BY t.schema_id, t.name
    ORDER BY TotalSpaceMB DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_IndexFragmentation
    @MinPageCount INT = 50,
    @MinFragmentationPercent DECIMAL(5,2) = 5.0
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
        ips.record_count AS RecordCount,
        CASE
            WHEN ips.avg_fragmentation_in_percent >= 30 AND ips.page_count >= @MinPageCount THEN N'Rebuild'
            WHEN ips.avg_fragmentation_in_percent >= 10 AND ips.page_count >= @MinPageCount THEN N'Reorganize'
            ELSE N'OK'
        END AS RecommendedAction
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, N'LIMITED') ips
    INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE ips.page_count >= @MinPageCount
      AND ips.avg_fragmentation_in_percent >= @MinFragmentationPercent
      AND i.name IS NOT NULL
    ORDER BY ips.avg_fragmentation_in_percent DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_BlockingSessions
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        blocked.session_id AS BlockedSessionId,
        blocking.session_id AS BlockingSessionId,
        blocked.wait_type AS WaitType,
        blocked.wait_time AS WaitTimeMs,
        blocked.wait_resource AS WaitResource,
        DB_NAME(blocked.database_id) AS DatabaseName,
        blocked_text.text AS BlockedQuery,
        blocking_text.text AS BlockingQuery,
        blocked.status AS BlockedStatus,
        blocking.status AS BlockingStatus
    FROM sys.dm_exec_requests blocked
    INNER JOIN sys.dm_exec_sessions blocking ON blocked.blocking_session_id = blocking.session_id
    LEFT JOIN sys.dm_exec_connections bc ON bc.session_id = blocking.session_id
    OUTER APPLY sys.dm_exec_sql_text(blocked.sql_handle) blocked_text
    OUTER APPLY sys.dm_exec_sql_text(bc.most_recent_sql_handle) blocking_text
    WHERE blocked.blocking_session_id <> 0
    ORDER BY blocked.wait_time DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_DeadlockStatistics
AS
BEGIN
    SET NOCOUNT ON;

    /* System-wide deadlock counters (where available) */
    SELECT
        counter_name AS CounterName,
        cntr_value AS CounterValue,
        instance_name AS InstanceName
    FROM sys.dm_os_performance_counters
    WHERE counter_name IN (
            N'Number of Deadlocks/sec',
            N'Lock Waits/sec',
            N'Lock Wait Time (ms)',
            N'Average Wait Time (ms)')
      AND (instance_name = N'_Total' OR instance_name = N'')
    ORDER BY counter_name;

    /* Recent deadlock graphs from system_health XEvent (best-effort) */
    BEGIN TRY
        ;WITH DeadlockEvents AS (
            SELECT
                CAST(event_data AS XML) AS EventXml,
                timestamp_utc
            FROM sys.fn_xe_file_target_read_file('system_health*.xel', NULL, NULL, NULL)
            WHERE object_name = N'xml_deadlock_report'
        )
        SELECT TOP (20)
            timestamp_utc AS DeadlockUtc,
            EventXml.value('(event/data/value)[1]', 'nvarchar(max)') AS DeadlockGraphPreview
        FROM DeadlockEvents
        ORDER BY timestamp_utc DESC;
    END TRY
    BEGIN CATCH
        SELECT
            CAST(NULL AS DATETIME2) AS DeadlockUtc,
            N'Deadlock XEvent history unavailable: ' + ERROR_MESSAGE() AS DeadlockGraphPreview
        WHERE 1 = 1;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_ActiveConnections
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COUNT(*) AS TotalSessions,
        SUM(CASE WHEN status = N'running' THEN 1 ELSE 0 END) AS RunningSessions,
        SUM(CASE WHEN status = N'sleeping' THEN 1 ELSE 0 END) AS SleepingSessions,
        SUM(CASE WHEN database_id = DB_ID() THEN 1 ELSE 0 END) AS SessionsOnThisDb
    FROM sys.dm_exec_sessions
    WHERE is_user_process = 1;

    SELECT TOP (50)
        s.session_id AS SessionId,
        s.login_name AS LoginName,
        s.host_name AS HostName,
        s.program_name AS ProgramName,
        s.status AS SessionStatus,
        DB_NAME(s.database_id) AS DatabaseName,
        s.cpu_time AS CpuTimeMs,
        s.memory_usage AS MemoryUsagePages,
        s.last_request_start_time AS LastRequestStart
    FROM sys.dm_exec_sessions s
    WHERE s.is_user_process = 1
      AND (s.database_id = DB_ID() OR s.database_id = 0)
    ORDER BY s.last_request_start_time DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_CaptureMetricSnapshot
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CapturedAt DATETIME2 = SYSUTCDATETIME();
    DECLARE @TotalSizeMB DECIMAL(18,4), @UsedSpaceMB DECIMAL(18,4), @UsedPercent DECIMAL(18,4);
    DECLARE @ActiveConnections INT, @AvgFragmentation DECIMAL(18,4);

    SELECT
        @TotalSizeMB = CAST(SUM(size) * 8.0 / 1024 AS DECIMAL(18,4)),
        @UsedSpaceMB = CAST(SUM(FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(18,4)),
        @UsedPercent = CAST(
            CASE WHEN SUM(size) = 0 THEN 0
                 ELSE SUM(FILEPROPERTY(name, 'SpaceUsed')) * 100.0 / SUM(size)
            END AS DECIMAL(18,4))
    FROM sys.database_files;

    SELECT @ActiveConnections = COUNT(*)
    FROM sys.dm_exec_sessions
    WHERE is_user_process = 1 AND database_id = DB_ID();

    SELECT @AvgFragmentation = AVG(CAST(ips.avg_fragmentation_in_percent AS DECIMAL(18,4)))
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, N'LIMITED') ips
    INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE ips.page_count >= 50 AND i.name IS NOT NULL;

    INSERT INTO dbo.DatabaseMetricSnapshot (CapturedAt, MetricCategory, MetricName, MetricValue, MetricUnit)
    VALUES
        (@CapturedAt, N'Size', N'TotalSizeMB', @TotalSizeMB, N'MB'),
        (@CapturedAt, N'Size', N'UsedSpaceMB', @UsedSpaceMB, N'MB'),
        (@CapturedAt, N'Size', N'UsedPercent', @UsedPercent, N'%'),
        (@CapturedAt, N'Connections', N'ActiveConnections', @ActiveConnections, N'count'),
        (@CapturedAt, N'Index', N'AvgFragmentationPercent', ISNULL(@AvgFragmentation, 0), N'%');

    /* Per-table row counts */
    INSERT INTO dbo.DatabaseMetricSnapshot (CapturedAt, MetricCategory, MetricName, MetricValue, MetricUnit, ExtraJson)
    SELECT
        @CapturedAt,
        N'TableGrowth',
        t.name,
        SUM(p.rows),
        N'rows',
        (SELECT CAST(SUM(a.total_pages) * 8.0 / 1024 AS DECIMAL(18,2)) AS TotalSpaceMB
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM sys.tables t
    INNER JOIN sys.indexes i ON t.object_id = i.object_id
    INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
    INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
    WHERE t.is_ms_shipped = 0 AND i.index_id <= 1
    GROUP BY t.name;

    SELECT @CapturedAt AS CapturedAt, COUNT(*) AS MetricsCaptured
    FROM dbo.DatabaseMetricSnapshot
    WHERE CapturedAt = @CapturedAt;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_HealthDashboard
AS
BEGIN
    SET NOCOUNT ON;

    /* Result set 1: database size */
    EXEC dbo.sp_Monitor_DatabaseGrowth;

    /* Result set 2: active connection summary */
    SELECT
        COUNT(*) AS TotalSessions,
        ISNULL(SUM(CASE WHEN status = N'running' THEN 1 ELSE 0 END), 0) AS RunningSessions,
        ISNULL(SUM(CASE WHEN database_id = DB_ID() THEN 1 ELSE 0 END), 0) AS SessionsOnThisDb
    FROM sys.dm_exec_sessions
    WHERE is_user_process = 1;

    /* Result set 3: fragmentation summary */
    SELECT
        CAST(AVG(ips.avg_fragmentation_in_percent) AS DECIMAL(5,2)) AS AvgFragmentationPercent,
        CAST(MAX(ips.avg_fragmentation_in_percent) AS DECIMAL(5,2)) AS MaxFragmentationPercent,
        ISNULL(SUM(CASE WHEN ips.avg_fragmentation_in_percent >= 30 THEN 1 ELSE 0 END), 0) AS IndexesNeedingRebuild,
        ISNULL(SUM(CASE WHEN ips.avg_fragmentation_in_percent >= 10 AND ips.avg_fragmentation_in_percent < 30 THEN 1 ELSE 0 END), 0) AS IndexesNeedingReorganize
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, N'LIMITED') ips
    INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE ips.page_count >= 50 AND i.name IS NOT NULL;

    /* Result set 4: archive statistics */
    SELECT N'LeaveRequests' AS EntityName,
           (SELECT COUNT(*) FROM dbo.LeaveRequests) AS LiveRows,
           (SELECT COUNT(*) FROM dbo.LeaveRequestsArchive) AS ArchivedRows
    UNION ALL
    SELECT N'Notifications',
           CASE WHEN OBJECT_ID(N'dbo.Notifications', N'U') IS NULL THEN 0 ELSE (SELECT COUNT(*) FROM dbo.Notifications) END,
           CASE WHEN OBJECT_ID(N'dbo.NotificationsArchive', N'U') IS NULL THEN 0 ELSE (SELECT COUNT(*) FROM dbo.NotificationsArchive) END
    UNION ALL
    SELECT N'AuditLogs',
           (SELECT COUNT(*) FROM dbo.AuditLogs),
           CASE WHEN OBJECT_ID(N'dbo.AuditLogsArchive', N'U') IS NULL THEN 0 ELSE (SELECT COUNT(*) FROM dbo.AuditLogsArchive) END
    UNION ALL
    SELECT N'LeaveBalances',
           CASE WHEN OBJECT_ID(N'dbo.LeaveBalances', N'U') IS NULL THEN 0 ELSE (SELECT COUNT(*) FROM dbo.LeaveBalances) END,
           CASE WHEN OBJECT_ID(N'dbo.LeaveBalancesArchive', N'U') IS NULL THEN 0 ELSE (SELECT COUNT(*) FROM dbo.LeaveBalancesArchive) END;

    /* Result set 5: recent maintenance history */
    SELECT TOP (20)
        MaintenanceRunId, JobName, StepName, StartTime, EndTime, Status, Details, ErrorMessage
    FROM dbo.MaintenanceRunLog
    ORDER BY MaintenanceRunId DESC;

    /* Result set 6: recent archive history */
    SELECT TOP (20)
        ArchiveRunId, ArchiveBatchId, EntityName, StartTime, EndTime, Status, RowsArchived, RetentionDays
    FROM dbo.ArchiveRunLog
    ORDER BY ArchiveRunId DESC;
END
GO

PRINT '03_Monitoring_Procedures.sql completed.';
GO
