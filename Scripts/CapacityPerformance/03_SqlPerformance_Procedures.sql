/*
================================================================================
  SQL Performance Dashboard Procedures
  Database: EmployeeLeaveDb
================================================================================
*/
USE EmployeeLeaveDb;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Perf_SlowQueryStatistics
    @TopN INT = 25,
    @MinElapsedMs BIGINT = 50
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@TopN)
        qs.execution_count AS ExecutionCount,
        qs.total_elapsed_time / 1000 AS TotalElapsedMs,
        qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000 AS AvgElapsedMs,
        qs.total_worker_time / 1000 AS TotalCpuMs,
        qs.total_logical_reads AS TotalLogicalReads,
        qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS AvgLogicalReads,
        qs.last_execution_time AS LastExecutionTime,
        OBJECT_NAME(st.objectid, st.dbid) AS ObjectName,
        LEFT(SUBSTRING(st.text, (qs.statement_start_offset / 2) + 1,
            ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)
              ELSE qs.statement_end_offset END - qs.statement_start_offset) / 2) + 1), 400) AS QueryText
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
    WHERE (DB_NAME(st.dbid) = DB_NAME() OR st.dbid IS NULL)
      AND (qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000) >= @MinElapsedMs
    ORDER BY qs.total_elapsed_time DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Perf_QueryExecutionTrends
    @HoursBack INT = 24
AS
BEGIN
    SET NOCOUNT ON;

    /* Plan-cache proxies grouped by hour of last execution within window */
    SELECT
        DATEADD(HOUR, DATEDIFF(HOUR, 0, qs.last_execution_time), 0) AS ExecutionHour,
        COUNT(*) AS DistinctPlans,
        SUM(qs.execution_count) AS TotalExecutions,
        SUM(qs.total_elapsed_time) / 1000 AS TotalElapsedMs,
        AVG(qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000) AS AvgElapsedMs,
        SUM(qs.total_logical_reads) AS TotalLogicalReads
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
    WHERE qs.last_execution_time >= DATEADD(HOUR, -@HoursBack, SYSUTCDATETIME())
      AND (DB_NAME(st.dbid) = DB_NAME() OR st.dbid IS NULL)
    GROUP BY DATEADD(HOUR, DATEDIFF(HOUR, 0, qs.last_execution_time), 0)
    ORDER BY ExecutionHour;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Perf_IndexUtilization
    @IncludeUnusedOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID(N'dbo.sp_Opt_IndexUsageStats', N'P') IS NOT NULL
    BEGIN
        EXEC dbo.sp_Opt_IndexUsageStats @IncludeUnusedOnly = @IncludeUnusedOnly;
        RETURN;
    END

    SELECT
        OBJECT_SCHEMA_NAME(i.object_id) AS SchemaName,
        OBJECT_NAME(i.object_id) AS TableName,
        i.name AS IndexName,
        i.type_desc AS IndexType,
        ISNULL(ius.user_seeks, 0) AS UserSeeks,
        ISNULL(ius.user_scans, 0) AS UserScans,
        ISNULL(ius.user_lookups, 0) AS UserLookups,
        ISNULL(ius.user_updates, 0) AS UserUpdates,
        ius.last_user_seek AS LastUserSeek,
        ius.last_user_scan AS LastUserScan,
        CASE
            WHEN i.type_desc = N'CLUSTERED' THEN N'Keep (clustered)'
            WHEN ISNULL(ius.user_seeks, 0) + ISNULL(ius.user_scans, 0) + ISNULL(ius.user_lookups, 0) = 0
                 THEN N'Unused since last restart'
            ELSE N'In use'
        END AS UsageStatus
    FROM sys.indexes i
    LEFT JOIN sys.dm_db_index_usage_stats ius
        ON i.object_id = ius.object_id AND i.index_id = ius.index_id AND ius.database_id = DB_ID()
    WHERE OBJECTPROPERTY(i.object_id, 'IsMsShipped') = 0
      AND i.name IS NOT NULL
      AND (
            @IncludeUnusedOnly = 0
            OR (ISNULL(ius.user_seeks, 0) + ISNULL(ius.user_scans, 0) + ISNULL(ius.user_lookups, 0) = 0
                AND i.type_desc <> N'CLUSTERED')
          )
    ORDER BY ISNULL(ius.user_seeks, 0) + ISNULL(ius.user_scans, 0) + ISNULL(ius.user_lookups, 0);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Perf_ActiveSessions
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.session_id AS SessionId,
        s.login_name AS LoginName,
        s.host_name AS HostName,
        s.program_name AS ProgramName,
        s.status AS SessionStatus,
        r.status AS RequestStatus,
        r.command AS Command,
        r.wait_type AS WaitType,
        r.wait_time AS WaitTimeMs,
        r.cpu_time AS CpuTimeMs,
        r.total_elapsed_time AS ElapsedTimeMs,
        r.blocking_session_id AS BlockingSessionId,
        DB_NAME(r.database_id) AS DatabaseName,
        LEFT(st.text, 300) AS QueryText
    FROM sys.dm_exec_sessions s
    LEFT JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
    OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) st
    WHERE s.is_user_process = 1
      AND (r.database_id = DB_ID() OR r.database_id IS NULL OR DB_NAME(r.database_id) = DB_NAME())
    ORDER BY ISNULL(r.total_elapsed_time, 0) DESC, s.session_id;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Perf_WaitStatistics
    @TopN INT = 25,
    @PersistSnapshot BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    /* Filter benign waits */
    ;WITH Waits AS (
        SELECT
            wait_type,
            waiting_tasks_count,
            wait_time_ms,
            max_wait_time_ms,
            signal_wait_time_ms,
            wait_time_ms - signal_wait_time_ms AS ResourceWaitTimeMs
        FROM sys.dm_os_wait_stats
        WHERE wait_type NOT LIKE N'SLEEP%'
          AND wait_type NOT LIKE N'BROKER%'
          AND wait_type NOT IN (
              N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT', N'LAZYWRITER_SLEEP',
              N'DIRTY_PAGE_POLL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
              N'SQLTRACE_BUFFER_FLUSH', N'XE_TIMER_EVENT', N'XE_DISPATCHER_WAIT',
              N'REQUEST_FOR_DEADLOCK_SEARCH', N'CHECKPOINT_QUEUE', N'LOGMGR_QUEUE',
              N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'BROKER_TO_FLUSH', N'BROKER_TASK_STOP')
          AND wait_time_ms > 0
    )
    SELECT TOP (@TopN)
        wait_type AS WaitType,
        waiting_tasks_count AS WaitingTasksCount,
        wait_time_ms AS WaitTimeMs,
        max_wait_time_ms AS MaxWaitTimeMs,
        signal_wait_time_ms AS SignalWaitTimeMs,
        ResourceWaitTimeMs,
        CAST(100.0 * wait_time_ms / NULLIF(SUM(wait_time_ms) OVER (), 0) AS DECIMAL(5,2)) AS WaitPercent
    FROM Waits
    ORDER BY wait_time_ms DESC;

    IF @PersistSnapshot = 1
    BEGIN
        INSERT INTO dbo.PerfWaitSnapshot
            (WaitType, WaitingTasksCount, WaitTimeMs, MaxWaitTimeMs, SignalWaitTimeMs)
        SELECT TOP (@TopN)
            wait_type, waiting_tasks_count, wait_time_ms, max_wait_time_ms, signal_wait_time_ms
        FROM sys.dm_os_wait_stats
        WHERE wait_type NOT LIKE N'SLEEP%'
          AND wait_time_ms > 0
        ORDER BY wait_time_ms DESC;
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Perf_ResourceConsumptionSummary
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CpuCount INT = (SELECT cpu_count FROM sys.dm_os_sys_info);
    DECLARE @PhysicalMemoryMB DECIMAL(18,2) =
        (SELECT CAST(physical_memory_kb / 1024.0 AS DECIMAL(18,2)) FROM sys.dm_os_sys_info);
    DECLARE @SqlMemoryMB DECIMAL(18,2) =
        (SELECT CAST(committed_kb / 1024.0 AS DECIMAL(18,2)) FROM sys.dm_os_sys_info);
    DECLARE @ActiveRequests INT =
        (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE database_id = DB_ID() AND session_id <> @@SPID);
    DECLARE @Blocked INT =
        (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE database_id = DB_ID() AND blocking_session_id <> 0);
    DECLARE @UserSessions INT =
        (SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE is_user_process = 1 AND database_id = DB_ID());
    DECLARE @DbSizeMB DECIMAL(18,2) =
        (SELECT CAST(SUM(size) * 8.0 / 1024 AS DECIMAL(18,2)) FROM sys.database_files);
    DECLARE @SignalWaitPct DECIMAL(5,2) =
        (SELECT CAST(100.0 * SUM(signal_wait_time_ms) / NULLIF(SUM(wait_time_ms), 0) AS DECIMAL(5,2))
         FROM sys.dm_os_wait_stats WHERE wait_time_ms > 0);

    SELECT
        DB_NAME() AS DatabaseName,
        @CpuCount AS CpuCount,
        @PhysicalMemoryMB AS PhysicalMemoryMB,
        @SqlMemoryMB AS SqlCommittedMemoryMB,
        @DbSizeMB AS DatabaseSizeMB,
        @UserSessions AS UserSessions,
        @ActiveRequests AS ActiveRequests,
        @Blocked AS BlockedRequests,
        @SignalWaitPct AS SignalWaitPercent,
        SYSUTCDATETIME() AS CapturedAtUtc;
END
GO

PRINT '03_SqlPerformance_Procedures completed.';
GO
