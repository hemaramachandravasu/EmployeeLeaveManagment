/*
================================================================================
  Operational Analytics + Partition Management Procedures
  Database: EmployeeLeaveDb

  Reports:
    • Database performance summary
    • Query execution statistics
    • Table growth analysis
    • Storage utilization (filegroup / partition)
    • Index health (partition-aware)
    • Partition inventory & boundary maintenance
================================================================================
*/
USE EmployeeLeaveDb;
GO

/* ---------- Performance summary ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_Report_PerformanceSummary
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DbSizeMB DECIMAL(18,2),
            @DataMB DECIMAL(18,2),
            @LogMB DECIMAL(18,2),
            @UsedMB DECIMAL(18,2);

    SELECT
        @DbSizeMB = CAST(SUM(size) * 8.0 / 1024 AS DECIMAL(18,2)),
        @DataMB = CAST(SUM(CASE WHEN type_desc = N'ROWS' THEN size ELSE 0 END) * 8.0 / 1024 AS DECIMAL(18,2)),
        @LogMB = CAST(SUM(CASE WHEN type_desc = N'LOG' THEN size ELSE 0 END) * 8.0 / 1024 AS DECIMAL(18,2)),
        @UsedMB = CAST(SUM(FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(18,2))
    FROM sys.database_files;

    SELECT
        DB_NAME() AS DatabaseName,
        @DbSizeMB AS TotalSizeMB,
        @DataMB AS DataSizeMB,
        @LogMB AS LogSizeMB,
        @UsedMB AS UsedSpaceMB,
        CAST(CASE WHEN @DbSizeMB = 0 THEN 0 ELSE @UsedMB * 100.0 / @DbSizeMB END AS DECIMAL(5,2)) AS UsedPercent,
        (SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE database_id = DB_ID() AND is_user_process = 1) AS ActiveUserSessions,
        (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE database_id = DB_ID() AND status = N'suspended') AS SuspendedRequests,
        (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE database_id = DB_ID() AND blocking_session_id <> 0) AS BlockedRequests,
        (SELECT COUNT(*) FROM sys.indexes i
         INNER JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
         WHERE i.index_id IN (0, 1)) AS PartitionedTables,
        (SELECT COUNT(*) FROM dbo.OptimizationRunLog WHERE StartTime >= DATEADD(DAY, -7, SYSUTCDATETIME()) AND Status = N'Failed') AS FailedOptJobsLast7Days,
        SYSUTCDATETIME() AS CapturedAtUtc;
END
GO

/* ---------- Query execution statistics ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_Report_QueryExecutionStats
    @TopN INT = 25
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
    WHERE DB_NAME(st.dbid) = DB_NAME() OR st.dbid IS NULL
    ORDER BY qs.total_elapsed_time DESC;
END
GO

/* ---------- Table growth analysis ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_Report_TableGrowth
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        OBJECT_SCHEMA_NAME(i.object_id) AS SchemaName,
        OBJECT_NAME(i.object_id) AS TableName,
        SUM(p.rows) AS RowCounts,
        CAST(SUM(a.total_pages) * 8.0 / 1024 AS DECIMAL(18,2)) AS TotalSpaceMB,
        CAST(SUM(a.used_pages) * 8.0 / 1024 AS DECIMAL(18,2)) AS UsedSpaceMB,
        CAST(SUM(a.data_pages) * 8.0 / 1024 AS DECIMAL(18,2)) AS DataSpaceMB,
        CASE WHEN ps.name IS NOT NULL THEN 1 ELSE 0 END AS IsPartitioned,
        ISNULL(ps.name, N'PRIMARY') AS PartitionSchemeOrFilegroup,
        COUNT(DISTINCT p.partition_number) AS PartitionCount
    FROM sys.indexes i
    INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
    INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
    LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
    WHERE i.index_id <= 1
      AND OBJECTPROPERTY(i.object_id, 'IsMsShipped') = 0
    GROUP BY i.object_id, ps.name
    ORDER BY SUM(a.total_pages) DESC;
END
GO

/* ---------- Storage utilization by filegroup / file ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_Report_StorageUtilization
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        fg.name AS FilegroupName,
        df.name AS LogicalFileName,
        df.physical_name AS PhysicalPath,
        df.type_desc AS FileType,
        CAST(df.size * 8.0 / 1024 AS DECIMAL(18,2)) AS SizeMB,
        CAST(FILEPROPERTY(df.name, 'SpaceUsed') * 8.0 / 1024 AS DECIMAL(18,2)) AS UsedMB,
        CAST((df.size - FILEPROPERTY(df.name, 'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(18,2)) AS FreeMB,
        CAST(
            CASE WHEN df.size = 0 THEN 0
                 ELSE FILEPROPERTY(df.name, 'SpaceUsed') * 100.0 / df.size
            END AS DECIMAL(5,2)) AS UsedPercent,
        df.growth AS GrowthSetting,
        CASE WHEN df.is_percent_growth = 1 THEN N'Percent' ELSE N'MB' END AS GrowthUnit
    FROM sys.database_files df
    LEFT JOIN sys.filegroups fg ON df.data_space_id = fg.data_space_id
    ORDER BY fg.name, df.file_id;
END
GO

/* ---------- Index health (partition-aware report) ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_Report_IndexHealth
    @MinPageCount INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Opt_IndexFragmentationAnalysis @MinPageCount = @MinPageCount;
END
GO

/* ---------- Partition inventory ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_Report_PartitionInfo
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        OBJECT_SCHEMA_NAME(p.object_id) AS SchemaName,
        OBJECT_NAME(p.object_id) AS TableName,
        i.name AS IndexName,
        p.partition_number AS PartitionNumber,
        fg.name AS FilegroupName,
        p.rows AS RowCounts,
        prv_left.value AS LowerBoundaryInclusive,
        prv_right.value AS UpperBoundaryExclusive,
        pf.name AS PartitionFunction,
        ps.name AS PartitionScheme,
        CAST(au.total_pages * 8.0 / 1024 AS DECIMAL(18,2)) AS TotalSpaceMB
    FROM sys.partitions p
    INNER JOIN sys.indexes i ON p.object_id = i.object_id AND p.index_id = i.index_id
    INNER JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
    INNER JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
    LEFT JOIN sys.partition_range_values prv_right
        ON pf.function_id = prv_right.function_id AND p.partition_number = prv_right.boundary_id + CASE WHEN pf.boundary_value_on_right = 1 THEN 0 ELSE 1 END
    LEFT JOIN sys.partition_range_values prv_left
        ON pf.function_id = prv_left.function_id AND p.partition_number = prv_left.boundary_id + CASE WHEN pf.boundary_value_on_right = 1 THEN 1 ELSE 0 END
    INNER JOIN sys.destination_data_spaces dds
        ON ps.data_space_id = dds.partition_scheme_id AND dds.destination_id = p.partition_number
    INNER JOIN sys.filegroups fg ON dds.data_space_id = fg.data_space_id
    OUTER APPLY (
        SELECT SUM(a.total_pages) AS total_pages
        FROM sys.allocation_units a
        WHERE a.container_id = p.partition_id
    ) au
    WHERE i.index_id IN (0, 1)
      AND (@TableName IS NULL OR OBJECT_NAME(p.object_id) = @TableName)
    ORDER BY TableName, PartitionNumber;
END
GO

/* ---------- Database health check (optimization-focused) ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_DatabaseHealthCheck
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunId INT;
    INSERT INTO dbo.OptimizationRunLog (JobName, StepName, Status)
    VALUES (N'ELM_Opt_Health_Check', N'DatabaseHealthCheck', N'Running');
    SET @RunId = SCOPE_IDENTITY();

    BEGIN TRY
        DECLARE @Issues NVARCHAR(MAX) = N'';

        /* Fragmented indexes */
        IF EXISTS (
            SELECT 1
            FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, N'LIMITED') ips
            INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
            WHERE ips.page_count >= 50 AND ips.avg_fragmentation_in_percent >= 30 AND i.name IS NOT NULL)
            SET @Issues += N'High fragmentation (>=30%) detected. ';

        /* Empty future partitions needed? Check Leave max CreatedDate vs last boundary */
        DECLARE @LastLeaveBoundary DATETIME2 =
            (SELECT MAX(CONVERT(DATETIME2, value))
             FROM sys.partition_range_values prv
             INNER JOIN sys.partition_functions pf ON prv.function_id = pf.function_id
             WHERE pf.name = N'PF_LeaveByCreatedDate');

        IF @LastLeaveBoundary IS NOT NULL AND @LastLeaveBoundary <= DATEADD(MONTH, 3, SYSUTCDATETIME())
            SET @Issues += N'Leave partition boundaries need SPLIT soon. ';

        DECLARE @LastAuditBoundary DATETIME2 =
            (SELECT MAX(CONVERT(DATETIME2, value))
             FROM sys.partition_range_values prv
             INNER JOIN sys.partition_functions pf ON prv.function_id = pf.function_id
             WHERE pf.name = N'PF_AuditByChangedOn');

        IF @LastAuditBoundary IS NOT NULL AND @LastAuditBoundary <= DATEADD(MONTH, 2, SYSUTCDATETIME())
            SET @Issues += N'Audit partition boundaries need SPLIT soon. ';

        IF @Issues = N'' SET @Issues = N'All optimization health checks passed.';

        SELECT
            DB_NAME() AS DatabaseName,
            CASE WHEN @Issues LIKE N'All optimization%' THEN N'Healthy' ELSE N'Attention' END AS HealthStatus,
            @Issues AS Details,
            SYSUTCDATETIME() AS CapturedAtUtc;

        UPDATE dbo.OptimizationRunLog
        SET EndTime = SYSUTCDATETIME(),
            Status = N'Success',
            Details = @Issues
        WHERE OptimizationRunId = @RunId;
    END TRY
    BEGIN CATCH
        UPDATE dbo.OptimizationRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Failed', ErrorMessage = ERROR_MESSAGE()
        WHERE OptimizationRunId = @RunId;
        THROW;
    END CATCH
END
GO

/* ---------- SPLIT next Leave yearly boundary ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_SplitLeavePartition
    @NewBoundary DATETIME2 = NULL,
    @TargetFilegroup SYSNAME = N'FG_Leave_Future'
AS
BEGIN
    SET NOCOUNT ON;

    IF @NewBoundary IS NULL
        SET @NewBoundary = DATETIME2FROMPARTS(YEAR(SYSUTCDATETIME()) + 2, 1, 1, 0, 0, 0, 0, 0);

    DECLARE @RunId INT;
    INSERT INTO dbo.OptimizationRunLog (JobName, StepName, Status)
    VALUES (N'ELM_Opt_Partition_Manage', N'SplitLeave', N'Running');
    SET @RunId = SCOPE_IDENTITY();

    BEGIN TRY
        /* NEXT USED filegroup for the scheme */
        DECLARE @Sql NVARCHAR(MAX) =
            N'ALTER PARTITION SCHEME PS_LeaveByCreatedDate NEXT USED ' + QUOTENAME(@TargetFilegroup) + N';'
          + N'ALTER PARTITION FUNCTION PF_LeaveByCreatedDate() SPLIT RANGE (' + QUOTENAME(CONVERT(NVARCHAR(30), @NewBoundary, 126), '''') + N');';

        EXEC sys.sp_executesql @Sql;

        UPDATE dbo.OptimizationRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Success',
            Details = N'Split Leave at ' + CONVERT(NVARCHAR(30), @NewBoundary, 126)
        WHERE OptimizationRunId = @RunId;
    END TRY
    BEGIN CATCH
        UPDATE dbo.OptimizationRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Failed', ErrorMessage = ERROR_MESSAGE()
        WHERE OptimizationRunId = @RunId;
        THROW;
    END CATCH
END
GO

/* ---------- SPLIT next Audit quarterly boundary ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_SplitAuditPartition
    @NewBoundary DATETIME2 = NULL,
    @TargetFilegroup SYSNAME = N'FG_Audit_Future'
AS
BEGIN
    SET NOCOUNT ON;

    IF @NewBoundary IS NULL
    BEGIN
        DECLARE @LastBoundary DATETIME2 =
            (SELECT MAX(CONVERT(DATETIME2, value))
             FROM sys.partition_range_values prv
             INNER JOIN sys.partition_functions pf ON prv.function_id = pf.function_id
             WHERE pf.name = N'PF_AuditByChangedOn');
        SET @NewBoundary = DATEADD(MONTH, 3, ISNULL(@LastBoundary, CAST(DATEFROMPARTS(YEAR(SYSUTCDATETIME()), ((MONTH(SYSUTCDATETIME()) - 1) / 3) * 3 + 1, 1) AS DATETIME2)));
    END

    DECLARE @RunId INT;
    INSERT INTO dbo.OptimizationRunLog (JobName, StepName, Status)
    VALUES (N'ELM_Opt_Partition_Manage', N'SplitAudit', N'Running');
    SET @RunId = SCOPE_IDENTITY();

    BEGIN TRY
        DECLARE @Sql NVARCHAR(MAX) =
            N'ALTER PARTITION SCHEME PS_AuditByChangedOn NEXT USED ' + QUOTENAME(@TargetFilegroup) + N';'
          + N'ALTER PARTITION FUNCTION PF_AuditByChangedOn() SPLIT RANGE (' + QUOTENAME(CONVERT(NVARCHAR(30), @NewBoundary, 126), '''') + N');';

        EXEC sys.sp_executesql @Sql;

        UPDATE dbo.OptimizationRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Success',
            Details = N'Split Audit at ' + CONVERT(NVARCHAR(30), @NewBoundary, 126)
        WHERE OptimizationRunId = @RunId;
    END TRY
    BEGIN CATCH
        UPDATE dbo.OptimizationRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Failed', ErrorMessage = ERROR_MESSAGE()
        WHERE OptimizationRunId = @RunId;
        THROW;
    END CATCH
END
GO

/* ---------- Orchestrator for scheduled health + optional auto-split ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_RunScheduledHealthAndPartitionCare
    @AutoSplit BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_Opt_DatabaseHealthCheck;

    IF @AutoSplit = 1
    BEGIN
        DECLARE @LeaveLast DATETIME2 =
            (SELECT MAX(CONVERT(DATETIME2, value))
             FROM sys.partition_range_values prv
             INNER JOIN sys.partition_functions pf ON prv.function_id = pf.function_id
             WHERE pf.name = N'PF_LeaveByCreatedDate');

        IF @LeaveLast IS NOT NULL AND @LeaveLast <= DATEADD(MONTH, 3, SYSUTCDATETIME())
            EXEC dbo.sp_Opt_SplitLeavePartition;

        DECLARE @AuditLast DATETIME2 =
            (SELECT MAX(CONVERT(DATETIME2, value))
             FROM sys.partition_range_values prv
             INNER JOIN sys.partition_functions pf ON prv.function_id = pf.function_id
             WHERE pf.name = N'PF_AuditByChangedOn');

        IF @AuditLast IS NOT NULL AND @AuditLast <= DATEADD(MONTH, 2, SYSUTCDATETIME())
            EXEC dbo.sp_Opt_SplitAuditPartition;
    END
END
GO

PRINT '06_Ops_Analytics_Procedures deployed.';
GO
