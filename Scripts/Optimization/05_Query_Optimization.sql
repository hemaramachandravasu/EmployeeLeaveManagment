/*
================================================================================
  Query / Procedure Performance Optimization Helpers
  Database: EmployeeLeaveDb

  Reviews plan-cache hot spots, recommends date predicates for partition
  elimination, and exposes optimized leave lookup wrappers that push
  CreatedDate filters when available.
================================================================================
*/
USE EmployeeLeaveDb;
GO

/* ---------- Slow query / plan cache summary ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_SlowQueryReview
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
        qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000 AS AvgCpuMs,
        qs.total_logical_reads AS TotalLogicalReads,
        qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS AvgLogicalReads,
        qs.total_logical_writes AS TotalLogicalWrites,
        qs.last_execution_time AS LastExecutionTime,
        qs.creation_time AS PlanCreationTime,
        OBJECT_NAME(st.objectid, st.dbid) AS ObjectName,
        SUBSTRING(st.text, (qs.statement_start_offset / 2) + 1,
            ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)
              ELSE qs.statement_end_offset END - qs.statement_start_offset) / 2) + 1) AS QueryText
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
    WHERE (DB_NAME(st.dbid) = DB_NAME() OR st.dbid IS NULL)
      AND (qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000) >= @MinElapsedMs
    ORDER BY qs.total_elapsed_time DESC;
END
GO

/* ---------- Redundant / duplicate index detection ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_FindRedundantIndexes
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH IndexCols AS (
        SELECT
            i.object_id,
            i.index_id,
            i.name AS IndexName,
            i.type_desc,
            KeyCols = STRING_AGG(c.name, N',') WITHIN GROUP (ORDER BY ic.key_ordinal),
            IncludeCols = STRING_AGG(CASE WHEN ic.is_included_column = 1 THEN c.name END, N',')
        FROM sys.indexes i
        INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE i.type > 0
          AND OBJECTPROPERTY(i.object_id, 'IsMsShipped') = 0
        GROUP BY i.object_id, i.index_id, i.name, i.type_desc
    )
    SELECT
        OBJECT_SCHEMA_NAME(a.object_id) AS SchemaName,
        OBJECT_NAME(a.object_id) AS TableName,
        a.IndexName AS IndexA,
        b.IndexName AS IndexB,
        a.KeyCols AS SharedKeyPrefix,
        N'Review: IndexB may be redundant if IncludeCols of A cover B' AS Recommendation
    FROM IndexCols a
    INNER JOIN IndexCols b
        ON a.object_id = b.object_id
       AND a.index_id < b.index_id
       AND (
            b.KeyCols = a.KeyCols
            OR b.KeyCols LIKE a.KeyCols + N',%'
            OR a.KeyCols LIKE b.KeyCols + N',%'
       )
    ORDER BY SchemaName, TableName;
END
GO

/* ---------- Optimized leave history with optional CreatedDate window ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_GetLeaveHistoryByDateWindow
    @EmployeeId INT = NULL,
    @FromCreatedDate DATETIME2 = NULL,
    @ToCreatedDate DATETIME2 = NULL,
    @Status NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    /*
      Prefer CreatedDate predicates so the optimizer can eliminate partitions
      on PS_LeaveByCreatedDate. Falls back to StartDate when CreatedDate
      window is omitted (still benefits from NC indexes).
    */
    SELECT
        lr.LeaveRequestId,
        lr.EmployeeId,
        e.FirstName + N' ' + e.LastName AS EmployeeName,
        lr.LeaveTypeId,
        lt.LeaveTypeName,
        lr.StartDate,
        lr.EndDate,
        lr.TotalDays,
        lr.Reason,
        lr.Status,
        lr.ApprovedBy,
        lr.ApprovedDate,
        lr.Remarks,
        lr.IsCancelled,
        lr.CreatedDate,
        lr.ModifiedDate
    FROM dbo.LeaveRequests lr
    INNER JOIN dbo.Employees e ON e.EmployeeId = lr.EmployeeId
    INNER JOIN dbo.LeaveTypes lt ON lt.LeaveTypeId = lr.LeaveTypeId
    WHERE (@EmployeeId IS NULL OR lr.EmployeeId = @EmployeeId)
      AND (@Status IS NULL OR lr.Status = @Status)
      AND (
            (@FromCreatedDate IS NULL OR lr.CreatedDate >= @FromCreatedDate)
            AND (@ToCreatedDate IS NULL OR lr.CreatedDate < @ToCreatedDate)
          )
      AND lr.IsCancelled = 0
    ORDER BY lr.CreatedDate DESC, lr.LeaveRequestId DESC
    OPTION (RECOMPILE);  /* avoid parameter sniffing across wide date ranges */
END
GO

/* ---------- Optimized audit lookup with ChangedOn window (partition elimination) ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_GetAuditByDateWindow
    @TableName NVARCHAR(128) = NULL,
    @FromChangedOn DATETIME2,
    @ToChangedOn DATETIME2,
    @ActionType NVARCHAR(20) = NULL,
    @TopN INT = 1000
AS
BEGIN
    SET NOCOUNT ON;

    IF @FromChangedOn IS NULL OR @ToChangedOn IS NULL
        THROW 50001, 'FromChangedOn and ToChangedOn are required for partition elimination.', 1;

    IF @ToChangedOn <= @FromChangedOn
        THROW 50002, 'ToChangedOn must be greater than FromChangedOn.', 1;

    SELECT TOP (@TopN)
        a.AuditId,
        a.TableName,
        a.RecordId,
        a.ActionType,
        a.ChangedBy,
        a.ChangedOn,
        a.OldValue,
        a.NewValue
    FROM dbo.AuditLogs a
    WHERE a.ChangedOn >= @FromChangedOn
      AND a.ChangedOn < @ToChangedOn
      AND (@TableName IS NULL OR a.TableName = @TableName)
      AND (@ActionType IS NULL OR a.ActionType = @ActionType)
    ORDER BY a.ChangedOn DESC, a.AuditId DESC
    OPTION (RECOMPILE);
END
GO

/* ---------- Update statistics (fullscan option for partitioned hot tables) ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_UpdateStatistics
    @FullScan BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunId INT;
    INSERT INTO dbo.OptimizationRunLog (JobName, StepName, Status)
    VALUES (N'ELM_Opt_Statistics_Update', N'UpdateStatistics', N'Running');
    SET @RunId = SCOPE_IDENTITY();

    DECLARE @Sql NVARCHAR(MAX) = N'';
    DECLARE @Schema SYSNAME, @Table SYSNAME;

    BEGIN TRY
        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT s.name, t.name
        FROM sys.tables t
        INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
        WHERE t.is_ms_shipped = 0;

        OPEN cur;
        FETCH NEXT FROM cur INTO @Schema, @Table;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Sql = N'UPDATE STATISTICS ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table)
                     + CASE WHEN @FullScan = 1 THEN N' WITH FULLSCAN;' ELSE N';' END;
            EXEC sys.sp_executesql @Sql;
            FETCH NEXT FROM cur INTO @Schema, @Table;
        END
        CLOSE cur;
        DEALLOCATE cur;

        UPDATE dbo.OptimizationRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Success',
            Details = CASE WHEN @FullScan = 1 THEN N'FULLSCAN on all user tables' ELSE N'Sampled update on all user tables' END
        WHERE OptimizationRunId = @RunId;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'cur') >= -1
        BEGIN
            CLOSE cur;
            DEALLOCATE cur;
        END

        UPDATE dbo.OptimizationRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Failed', ErrorMessage = ERROR_MESSAGE()
        WHERE OptimizationRunId = @RunId;
        THROW;
    END CATCH
END
GO

PRINT '05_Query_Optimization procedures deployed.';
GO
