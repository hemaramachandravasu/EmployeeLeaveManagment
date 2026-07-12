/*
================================================================================
  Automated Maintenance Procedures
  Database: EmployeeLeaveDb
================================================================================
*/
USE EmployeeLeaveDb;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Maint_LogStart
    @JobName  NVARCHAR(128),
    @StepName NVARCHAR(128),
    @MaintenanceRunId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.MaintenanceRunLog (JobName, StepName, Status)
    VALUES (@JobName, @StepName, N'Running');
    SET @MaintenanceRunId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Maint_LogEnd
    @MaintenanceRunId INT,
    @Status NVARCHAR(20),
    @Details NVARCHAR(MAX) = NULL,
    @ErrorMessage NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.MaintenanceRunLog
    SET EndTime = SYSUTCDATETIME(),
        Status = @Status,
        Details = @Details,
        ErrorMessage = @ErrorMessage
    WHERE MaintenanceRunId = @MaintenanceRunId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Maint_IndexOptimize
    @RebuildThresholdPercent DECIMAL(5,2) = 30.0,
    @ReorganizeThresholdPercent DECIMAL(5,2) = 10.0,
    @MinPageCount INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunId INT, @Sql NVARCHAR(MAX), @Details NVARCHAR(MAX) = N'';
    DECLARE @Schema SYSNAME, @Table SYSNAME, @Index SYSNAME, @Frag DECIMAL(5,2), @Action NVARCHAR(20);

    EXEC dbo.sp_Maint_LogStart N'ELM_Index_Maintenance', N'IndexOptimize', @RunId OUTPUT;

    BEGIN TRY
        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            OBJECT_SCHEMA_NAME(ips.object_id),
            OBJECT_NAME(ips.object_id),
            i.name,
            CAST(ips.avg_fragmentation_in_percent AS DECIMAL(5,2)),
            CASE
                WHEN ips.avg_fragmentation_in_percent >= @RebuildThresholdPercent THEN N'REBUILD'
                WHEN ips.avg_fragmentation_in_percent >= @ReorganizeThresholdPercent THEN N'REORGANIZE'
                ELSE N'SKIP'
            END
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, N'LIMITED') ips
        INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
        WHERE ips.page_count >= @MinPageCount
          AND i.name IS NOT NULL
          AND ips.avg_fragmentation_in_percent >= @ReorganizeThresholdPercent
          AND OBJECTPROPERTY(ips.object_id, 'IsMsShipped') = 0;

        OPEN cur;
        FETCH NEXT FROM cur INTO @Schema, @Table, @Index, @Frag, @Action;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @Action = N'REBUILD'
                SET @Sql = N'ALTER INDEX ' + QUOTENAME(@Index) + N' ON ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table)
                         + N' REBUILD WITH (ONLINE = OFF);';
            ELSE IF @Action = N'REORGANIZE'
                SET @Sql = N'ALTER INDEX ' + QUOTENAME(@Index) + N' ON ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table)
                         + N' REORGANIZE;';
            ELSE
                SET @Sql = NULL;

            IF @Sql IS NOT NULL
            BEGIN
                EXEC sys.sp_executesql @Sql;
                SET @Details = @Details + @Action + N' ' + @Schema + N'.' + @Table + N'.' + @Index
                             + N' (' + CAST(@Frag AS NVARCHAR(20)) + N'%); ';
            END

            FETCH NEXT FROM cur INTO @Schema, @Table, @Index, @Frag, @Action;
        END

        CLOSE cur;
        DEALLOCATE cur;

        IF @Details = N'' SET @Details = N'No indexes required maintenance.';
        EXEC dbo.sp_Maint_LogEnd @RunId, N'Success', @Details;
        SELECT @Details AS MaintenanceDetails, N'Success' AS Status;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'cur') >= 0
        BEGIN
            CLOSE cur;
            DEALLOCATE cur;
        END
        EXEC dbo.sp_Maint_LogEnd @RunId, N'Failed', NULL, ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Maint_UpdateStatistics
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunId INT, @Sql NVARCHAR(MAX), @Details NVARCHAR(MAX) = N'';
    DECLARE @Schema SYSNAME, @Table SYSNAME;

    EXEC dbo.sp_Maint_LogStart N'ELM_Statistics_Update', N'UpdateStatistics', @RunId OUTPUT;

    BEGIN TRY
        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT SCHEMA_NAME(schema_id), name
        FROM sys.tables
        WHERE is_ms_shipped = 0;

        OPEN cur;
        FETCH NEXT FROM cur INTO @Schema, @Table;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Sql = N'UPDATE STATISTICS ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table) + N' WITH FULLSCAN;';
            EXEC sys.sp_executesql @Sql;
            SET @Details = @Details + @Schema + N'.' + @Table + N'; ';
            FETCH NEXT FROM cur INTO @Schema, @Table;
        END

        CLOSE cur;
        DEALLOCATE cur;

        EXEC dbo.sp_Maint_LogEnd @RunId, N'Success', @Details;
        SELECT @Details AS UpdatedTables, N'Success' AS Status;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'cur') >= 0
        BEGIN
            CLOSE cur;
            DEALLOCATE cur;
        END
        EXEC dbo.sp_Maint_LogEnd @RunId, N'Failed', NULL, ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Maint_TempDataCleanup
    @MetricSnapshotRetentionDays INT = 180,
    @ArchiveLogRetentionDays INT = 365,
    @UnreadNotificationRetentionDays INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunId INT, @DeletedMetrics INT = 0, @DeletedMaint INT = 0,
            @DeletedArchiveLogs INT = 0, @DeletedStaleNotifications INT = 0;

    EXEC dbo.sp_Maint_LogStart N'ELM_Temp_Cleanup', N'TempDataCleanup', @RunId OUTPUT;

    BEGIN TRY
        DELETE FROM dbo.DatabaseMetricSnapshot
        WHERE CapturedAt < DATEADD(DAY, -@MetricSnapshotRetentionDays, SYSUTCDATETIME());
        SET @DeletedMetrics = @@ROWCOUNT;

        DELETE FROM dbo.MaintenanceRunLog
        WHERE StartTime < DATEADD(DAY, -365, SYSUTCDATETIME())
          AND Status <> N'Running';
        SET @DeletedMaint = @@ROWCOUNT;

        DELETE FROM dbo.ArchiveRunLog
        WHERE StartTime < DATEADD(DAY, -@ArchiveLogRetentionDays, SYSUTCDATETIME())
          AND Status <> N'Running';
        SET @DeletedArchiveLogs = @@ROWCOUNT;

        /* Unread notifications older than retention are treated as stale temp data */
        DELETE FROM dbo.Notifications
        WHERE IsRead = 0
          AND CreatedAt < DATEADD(DAY, -@UnreadNotificationRetentionDays, SYSUTCDATETIME());
        SET @DeletedStaleNotifications = @@ROWCOUNT;

        DECLARE @Details NVARCHAR(500) =
            N'MetricSnapshots=' + CAST(@DeletedMetrics AS NVARCHAR(20))
          + N'; MaintenanceLogs=' + CAST(@DeletedMaint AS NVARCHAR(20))
          + N'; ArchiveLogs=' + CAST(@DeletedArchiveLogs AS NVARCHAR(20))
          + N'; StaleNotifications=' + CAST(@DeletedStaleNotifications AS NVARCHAR(20));

        EXEC dbo.sp_Maint_LogEnd @RunId, N'Success', @Details;
        SELECT @DeletedMetrics AS MetricRowsDeleted,
               @DeletedMaint AS MaintenanceLogRowsDeleted,
               @DeletedArchiveLogs AS ArchiveLogRowsDeleted,
               @DeletedStaleNotifications AS StaleNotificationsDeleted,
               N'Success' AS Status;
    END TRY
    BEGIN CATCH
        EXEC dbo.sp_Maint_LogEnd @RunId, N'Failed', NULL, ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Maint_IntegrityCheck
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunId INT, @DbName SYSNAME = DB_NAME();
    EXEC dbo.sp_Maint_LogStart N'ELM_Integrity_Check', N'DBCC_CHECKDB', @RunId OUTPUT;

    BEGIN TRY
        DBCC CHECKDB (@DbName) WITH NO_INFOMSGS, ALL_ERRORMSGS;
        EXEC dbo.sp_Maint_LogEnd @RunId, N'Success', N'DBCC CHECKDB completed with no errors reported.';
        SELECT N'Success' AS Status, N'DBCC CHECKDB completed.' AS Details;
    END TRY
    BEGIN CATCH
        EXEC dbo.sp_Maint_LogEnd @RunId, N'Failed', NULL, ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Maint_RunArchiveJob
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunId INT;
    EXEC dbo.sp_Maint_LogStart N'ELM_Archive_Execution', N'ArchiveRunAll', @RunId OUTPUT;

    BEGIN TRY
        EXEC dbo.sp_Archive_RunAll;
        EXEC dbo.sp_Maint_LogEnd @RunId, N'Success', N'sp_Archive_RunAll completed.';
    END TRY
    BEGIN CATCH
        EXEC dbo.sp_Maint_LogEnd @RunId, N'Failed', NULL, ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

PRINT '04_Maintenance_Procedures.sql completed.';
GO
