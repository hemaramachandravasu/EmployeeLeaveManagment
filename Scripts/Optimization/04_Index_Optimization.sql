/*
================================================================================
  Advanced Index Management
  Database: EmployeeLeaveDb

  • Covering / filtered indexes for remaining hot tables
  • Partition-aware fragmentation analysis
  • Index usage & unused-index review
  • Rebuild / reorganize automation (partition-aware when applicable)
================================================================================
*/
USE EmployeeLeaveDb;
GO

/* ---------- Additional covering indexes (idempotent) ---------- */

/* Employees: manager hierarchy lookups */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Employees') AND name = N'IX_Employees_ManagerId')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Employees_ManagerId
        ON dbo.Employees (ManagerId)
        INCLUDE (FirstName, LastName, DepartmentId, IsActive)
        WHERE ManagerId IS NOT NULL AND IsActive = 1;
END
GO

/* Users: login path covering */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Users') AND name = N'IX_Users_UserName_Active')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Users_UserName_Active
        ON dbo.Users (UserName)
        INCLUDE (PasswordHash, Email, RoleId, EmployeeId, IsActive)
        WHERE IsActive = 1;
END
GO

/* LeaveTypes: active catalog */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.LeaveTypes') AND name = N'IX_LeaveTypes_IsActive')
BEGIN
    CREATE NONCLUSTERED INDEX IX_LeaveTypes_IsActive
        ON dbo.LeaveTypes (IsActive)
        INCLUDE (LeaveTypeName, TotalDays);
END
GO

PRINT 'Covering / filtered indexes ensured.';
GO

/* ---------- Fragmentation analysis (partition-aware) ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_IndexFragmentationAnalysis
    @MinPageCount INT = 50,
    @SchemaName SYSNAME = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        OBJECT_SCHEMA_NAME(ips.object_id) AS SchemaName,
        OBJECT_NAME(ips.object_id) AS TableName,
        i.name AS IndexName,
        ips.partition_number AS PartitionNumber,
        ips.index_type_desc AS IndexType,
        CAST(ips.avg_fragmentation_in_percent AS DECIMAL(5,2)) AS FragmentationPercent,
        ips.page_count AS PageCount,
        ips.avg_page_space_used_in_percent AS AvgPageSpaceUsedPercent,
        CASE
            WHEN ips.avg_fragmentation_in_percent >= 30 THEN N'Rebuild'
            WHEN ips.avg_fragmentation_in_percent >= 10 THEN N'Reorganize'
            ELSE N'Healthy'
        END AS RecommendedAction,
        CASE WHEN ps.name IS NOT NULL THEN 1 ELSE 0 END AS IsPartitionAligned,
        ps.name AS PartitionScheme
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, N'LIMITED') ips
    INNER JOIN sys.indexes i
        ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    LEFT JOIN sys.partition_schemes ps
        ON i.data_space_id = ps.data_space_id
    WHERE ips.page_count >= @MinPageCount
      AND i.name IS NOT NULL
      AND OBJECTPROPERTY(ips.object_id, 'IsMsShipped') = 0
      AND (@SchemaName IS NULL OR OBJECT_SCHEMA_NAME(ips.object_id) = @SchemaName)
      AND (@TableName IS NULL OR OBJECT_NAME(ips.object_id) = @TableName)
    ORDER BY ips.avg_fragmentation_in_percent DESC, ips.page_count DESC;
END
GO

/* ---------- Index usage statistics ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_IndexUsageStats
    @IncludeUnusedOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        OBJECT_SCHEMA_NAME(i.object_id) AS SchemaName,
        OBJECT_NAME(i.object_id) AS TableName,
        i.name AS IndexName,
        i.type_desc AS IndexType,
        ius.user_seeks AS UserSeeks,
        ius.user_scans AS UserScans,
        ius.user_lookups AS UserLookups,
        ius.user_updates AS UserUpdates,
        ius.last_user_seek AS LastUserSeek,
        ius.last_user_scan AS LastUserScan,
        CASE
            WHEN i.type_desc = N'CLUSTERED' THEN N'Keep (clustered)'
            WHEN ISNULL(ius.user_seeks, 0) + ISNULL(ius.user_scans, 0) + ISNULL(ius.user_lookups, 0) = 0
                 AND ISNULL(ius.user_updates, 0) > 0 THEN N'Candidate unused (write-only)'
            WHEN ISNULL(ius.user_seeks, 0) + ISNULL(ius.user_scans, 0) + ISNULL(ius.user_lookups, 0) = 0
                 THEN N'Unused since last restart'
            ELSE N'In use'
        END AS UsageStatus
    FROM sys.indexes i
    LEFT JOIN sys.dm_db_index_usage_stats ius
        ON i.object_id = ius.object_id
       AND i.index_id = ius.index_id
       AND ius.database_id = DB_ID()
    WHERE OBJECTPROPERTY(i.object_id, 'IsMsShipped') = 0
      AND i.name IS NOT NULL
      AND i.is_primary_key = 0
      AND (
            @IncludeUnusedOnly = 0
            OR (
                ISNULL(ius.user_seeks, 0) + ISNULL(ius.user_scans, 0) + ISNULL(ius.user_lookups, 0) = 0
                AND i.type_desc <> N'CLUSTERED'
            )
          )
    ORDER BY
        ISNULL(ius.user_seeks, 0) + ISNULL(ius.user_scans, 0) + ISNULL(ius.user_lookups, 0),
        ius.user_updates DESC;
END
GO

/* ---------- Missing index recommendations ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_MissingIndexRecommendations
    @TopN INT = 25
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@TopN)
        CONVERT(DECIMAL(18,2), migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans)) AS ImprovementScore,
        mid.statement AS TableName,
        mid.equality_columns AS EqualityColumns,
        mid.inequality_columns AS InequalityColumns,
        mid.included_columns AS IncludedColumns,
        migs.user_seeks AS UserSeeks,
        migs.user_scans AS UserScans,
        migs.avg_total_user_cost AS AvgTotalUserCost,
        migs.avg_user_impact AS AvgUserImpactPercent,
        migs.last_user_seek AS LastUserSeek,
        N'CREATE NONCLUSTERED INDEX IX_'
            + REPLACE(REPLACE(REPLACE(ISNULL(mid.equality_columns, N'') + ISNULL(mid.inequality_columns, N''), N'[', N''), N']', N''), N', ', N'_')
            + N' ON ' + mid.statement
            + N' (' + ISNULL(mid.equality_columns, N'')
            + CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN N', ' ELSE N'' END
            + ISNULL(mid.inequality_columns, N'') + N')'
            + CASE WHEN mid.included_columns IS NOT NULL THEN N' INCLUDE (' + mid.included_columns + N')' ELSE N'' END
            + N';' AS CreateIndexScript
    FROM sys.dm_db_missing_index_groups mig
    INNER JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
    INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
    WHERE mid.database_id = DB_ID()
    ORDER BY ImprovementScore DESC;
END
GO

/* ---------- Partition-aware index rebuild / reorganize ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Opt_IndexRebuildReorganize
    @RebuildThresholdPercent DECIMAL(5,2) = 30.0,
    @ReorganizeThresholdPercent DECIMAL(5,2) = 10.0,
    @MinPageCount INT = 50,
    @OnlineRebuild BIT = 0  -- requires Enterprise/Developer; ignored when unsupported
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunId INT;
    INSERT INTO dbo.OptimizationRunLog (JobName, StepName, Status)
    VALUES (N'ELM_Opt_Index_Maintenance', N'IndexRebuildReorganize', N'Running');
    SET @RunId = SCOPE_IDENTITY();

    DECLARE @Sql NVARCHAR(MAX), @Details NVARCHAR(MAX) = N'';
    DECLARE @Schema SYSNAME, @Table SYSNAME, @Index SYSNAME, @Frag DECIMAL(5,2);
    DECLARE @PartitionNumber INT, @Action NVARCHAR(20), @PartitionCount INT;

    BEGIN TRY
        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            OBJECT_SCHEMA_NAME(ips.object_id),
            OBJECT_NAME(ips.object_id),
            i.name,
            CAST(ips.avg_fragmentation_in_percent AS DECIMAL(5,2)),
            ips.partition_number,
            CASE
                WHEN ips.avg_fragmentation_in_percent >= @RebuildThresholdPercent THEN N'REBUILD'
                WHEN ips.avg_fragmentation_in_percent >= @ReorganizeThresholdPercent THEN N'REORGANIZE'
                ELSE N'SKIP'
            END,
            (SELECT COUNT(*) FROM sys.partitions p WHERE p.object_id = i.object_id AND p.index_id = i.index_id)
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, N'LIMITED') ips
        INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
        WHERE ips.page_count >= @MinPageCount
          AND i.name IS NOT NULL
          AND ips.avg_fragmentation_in_percent >= @ReorganizeThresholdPercent
          AND OBJECTPROPERTY(ips.object_id, 'IsMsShipped') = 0;

        OPEN cur;
        FETCH NEXT FROM cur INTO @Schema, @Table, @Index, @Frag, @PartitionNumber, @Action, @PartitionCount;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @Action = N'REBUILD'
            BEGIN
                IF @PartitionCount > 1
                    SET @Sql = N'ALTER INDEX ' + QUOTENAME(@Index) + N' ON ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table)
                             + N' REBUILD PARTITION = ' + CAST(@PartitionNumber AS NVARCHAR(10))
                             + CASE WHEN @OnlineRebuild = 1 THEN N' WITH (ONLINE = ON)' ELSE N'' END + N';';
                ELSE
                    SET @Sql = N'ALTER INDEX ' + QUOTENAME(@Index) + N' ON ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table)
                             + N' REBUILD'
                             + CASE WHEN @OnlineRebuild = 1 THEN N' WITH (ONLINE = ON)' ELSE N'' END + N';';
            END
            ELSE IF @Action = N'REORGANIZE'
            BEGIN
                IF @PartitionCount > 1
                    SET @Sql = N'ALTER INDEX ' + QUOTENAME(@Index) + N' ON ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table)
                             + N' REORGANIZE PARTITION = ' + CAST(@PartitionNumber AS NVARCHAR(10)) + N';';
                ELSE
                    SET @Sql = N'ALTER INDEX ' + QUOTENAME(@Index) + N' ON ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table)
                             + N' REORGANIZE;';
            END
            ELSE
                SET @Sql = NULL;

            IF @Sql IS NOT NULL
            BEGIN
                BEGIN TRY
                    EXEC sys.sp_executesql @Sql;
                    SET @Details = @Details + @Action + N' ' + @Schema + N'.' + @Table + N'.' + @Index
                                 + N' P' + CAST(@PartitionNumber AS NVARCHAR(10))
                                 + N' (' + CAST(@Frag AS NVARCHAR(20)) + N'%); ';
                END TRY
                BEGIN CATCH
                    /* ONLINE may fail on Standard — retry OFFLINE once for REBUILD */
                    IF @Action = N'REBUILD' AND @OnlineRebuild = 1
                    BEGIN
                        SET @Sql = REPLACE(@Sql, N'WITH (ONLINE = ON)', N'');
                        EXEC sys.sp_executesql @Sql;
                        SET @Details = @Details + N'REBUILD(offline-fallback) ' + @Schema + N'.' + @Table + N'.' + @Index
                                     + N' P' + CAST(@PartitionNumber AS NVARCHAR(10)) + N'; ';
                    END
                    ELSE
                        SET @Details = @Details + N'ERROR ' + @Schema + N'.' + @Table + N'.' + @Index
                                     + N': ' + ERROR_MESSAGE() + N'; ';
                END CATCH
            END

            FETCH NEXT FROM cur INTO @Schema, @Table, @Index, @Frag, @PartitionNumber, @Action, @PartitionCount;
        END

        CLOSE cur;
        DEALLOCATE cur;

        IF @Details = N'' SET @Details = N'No indexes required maintenance.';

        UPDATE dbo.OptimizationRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Success', Details = @Details
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

PRINT '04_Index_Optimization procedures deployed.';
GO
