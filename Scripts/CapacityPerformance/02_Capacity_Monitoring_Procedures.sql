/*
================================================================================
  Capacity Planning Monitoring Procedures
  Database: EmployeeLeaveDb
================================================================================
*/
USE EmployeeLeaveDb;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CapPerf_LogStart
    @JobName NVARCHAR(128),
    @StepName NVARCHAR(128),
    @RunId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.CapacityPerfRunLog (JobName, StepName, Status)
    VALUES (@JobName, @StepName, N'Running');
    SET @RunId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CapPerf_LogEnd
    @RunId INT,
    @Status NVARCHAR(20),
    @Details NVARCHAR(MAX) = NULL,
    @ErrorMessage NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.CapacityPerfRunLog
    SET EndTime = SYSUTCDATETIME(), Status = @Status, Details = @Details, ErrorMessage = @ErrorMessage
    WHERE RunId = @RunId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Cap_DatabaseGrowthTrends
    @DaysBack INT = 90
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 FROM dbo.DatabaseMetricSnapshot
        WHERE MetricCategory = N'Size'
          AND CapturedAt >= DATEADD(DAY, -@DaysBack, SYSUTCDATETIME()))
    BEGIN
        SELECT
            CAST(CapturedAt AS DATE) AS MetricDate,
            MAX(CASE WHEN MetricName = N'TotalSizeMB' THEN MetricValue END) AS TotalSizeMB,
            MAX(CASE WHEN MetricName = N'UsedSpaceMB' THEN MetricValue END) AS UsedSpaceMB,
            MAX(CASE WHEN MetricName = N'UsedPercent' THEN MetricValue END) AS UsedPercent
        FROM dbo.DatabaseMetricSnapshot
        WHERE MetricCategory = N'Size'
          AND CapturedAt >= DATEADD(DAY, -@DaysBack, SYSUTCDATETIME())
        GROUP BY CAST(CapturedAt AS DATE)
        ORDER BY MetricDate;
        RETURN;
    END

    /* Fallback live snapshot */
    SELECT
        CAST(SYSUTCDATETIME() AS DATE) AS MetricDate,
        CAST(SUM(size) * 8.0 / 1024 AS DECIMAL(18,2)) AS TotalSizeMB,
        CAST(SUM(FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(18,2)) AS UsedSpaceMB,
        CAST(CASE WHEN SUM(size) = 0 THEN 0
                  ELSE SUM(FILEPROPERTY(name, 'SpaceUsed')) * 100.0 / SUM(size) END AS DECIMAL(5,2)) AS UsedPercent
    FROM sys.database_files;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Cap_TableSizeAnalysis
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
        CAST((SUM(a.total_pages) - SUM(a.used_pages)) * 8.0 / 1024 AS DECIMAL(18,2)) AS UnusedSpaceMB
    FROM sys.indexes i
    INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
    INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
    WHERE i.index_id <= 1
      AND OBJECTPROPERTY(i.object_id, 'IsMsShipped') = 0
    GROUP BY i.object_id
    ORDER BY SUM(a.total_pages) DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Cap_StorageUtilization
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        df.name AS LogicalFileName,
        df.physical_name AS PhysicalPath,
        df.type_desc AS FileType,
        fg.name AS FilegroupName,
        CAST(df.size * 8.0 / 1024 AS DECIMAL(18,2)) AS SizeMB,
        CAST(FILEPROPERTY(df.name, 'SpaceUsed') * 8.0 / 1024 AS DECIMAL(18,2)) AS UsedMB,
        CAST((df.size - FILEPROPERTY(df.name, 'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(18,2)) AS FreeMB,
        CAST(CASE WHEN df.size = 0 THEN 0
                  ELSE FILEPROPERTY(df.name, 'SpaceUsed') * 100.0 / df.size END AS DECIMAL(5,2)) AS UsedPercent,
        CASE WHEN df.is_percent_growth = 1 THEN CAST(df.growth AS NVARCHAR(20)) + N'%'
             ELSE CAST(df.growth * 8 / 1024 AS NVARCHAR(20)) + N' MB' END AS Autogrowth
    FROM sys.database_files df
    LEFT JOIN sys.filegroups fg ON df.data_space_id = fg.data_space_id
    ORDER BY df.type_desc, fg.name, df.file_id;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Cap_FilegroupUtilization
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ISNULL(fg.name, N'(LOG)') AS FilegroupName,
        COUNT(df.file_id) AS FileCount,
        CAST(SUM(df.size) * 8.0 / 1024 AS DECIMAL(18,2)) AS SizeMB,
        CAST(SUM(FILEPROPERTY(df.name, 'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(18,2)) AS UsedMB,
        CAST(SUM(df.size - FILEPROPERTY(df.name, 'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(18,2)) AS FreeMB,
        CAST(CASE WHEN SUM(df.size) = 0 THEN 0
                  ELSE SUM(FILEPROPERTY(df.name, 'SpaceUsed')) * 100.0 / SUM(df.size) END AS DECIMAL(5,2)) AS UsedPercent
    FROM sys.database_files df
    LEFT JOIN sys.filegroups fg ON df.data_space_id = fg.data_space_id
    GROUP BY fg.name
    ORDER BY UsedPercent DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Cap_ForecastCapacity
    @LookbackDays INT = 90
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentTotal DECIMAL(18,2), @CurrentUsed DECIMAL(18,2);
    SELECT
        @CurrentTotal = CAST(SUM(size) * 8.0 / 1024 AS DECIMAL(18,2)),
        @CurrentUsed = CAST(SUM(FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(18,2))
    FROM sys.database_files
    WHERE type_desc = N'ROWS';

    DECLARE @OldestUsed DECIMAL(18,4), @NewestUsed DECIMAL(18,4), @DaySpan INT;

    ;WITH SizeHist AS (
        SELECT
            CapturedAt,
            MetricValue,
            ROW_NUMBER() OVER (ORDER BY CapturedAt ASC) AS rnAsc,
            ROW_NUMBER() OVER (ORDER BY CapturedAt DESC) AS rnDesc
        FROM dbo.DatabaseMetricSnapshot
        WHERE MetricCategory = N'Size'
          AND MetricName = N'UsedSpaceMB'
          AND CapturedAt >= DATEADD(DAY, -@LookbackDays, SYSUTCDATETIME())
    )
    SELECT
        @OldestUsed = MAX(CASE WHEN rnAsc = 1 THEN MetricValue END),
        @NewestUsed = MAX(CASE WHEN rnDesc = 1 THEN MetricValue END),
        @DaySpan = DATEDIFF(DAY,
            MAX(CASE WHEN rnAsc = 1 THEN CapturedAt END),
            MAX(CASE WHEN rnDesc = 1 THEN CapturedAt END))
    FROM SizeHist;

    DECLARE @AvgDaily DECIMAL(18,4) = 0;
    IF @DaySpan IS NOT NULL AND @DaySpan > 0 AND @OldestUsed IS NOT NULL AND @NewestUsed IS NOT NULL
        SET @AvgDaily = (@NewestUsed - @OldestUsed) / @DaySpan;

    /* If no history, assume 0.5% of current used per day as conservative placeholder */
    IF @AvgDaily <= 0
        SET @AvgDaily = CASE WHEN @CurrentUsed > 0 THEN @CurrentUsed * 0.005 ELSE 1 END;

    DECLARE @FreeMB DECIMAL(18,2) = @CurrentTotal - @CurrentUsed;
    IF @FreeMB < 0 SET @FreeMB = 0;

    DECLARE @DaysUntilFull INT =
        CASE WHEN @AvgDaily <= 0 THEN NULL
             ELSE CAST(CEILING(@FreeMB / @AvgDaily) AS INT) END;

    DECLARE @Proj30 DECIMAL(18,2) = @CurrentUsed + (@AvgDaily * 30);
    DECLARE @Proj90 DECIMAL(18,2) = @CurrentUsed + (@AvgDaily * 90);
    DECLARE @Method NVARCHAR(50) =
        CASE WHEN @DaySpan IS NOT NULL AND @DaySpan > 0 THEN N'LinearHistory' ELSE N'ConservativeEstimate' END;

    INSERT INTO dbo.CapacityForecastCache
        (DatabaseName, CurrentSizeMB, UsedSpaceMB, AvgDailyGrowthMB,
         ProjectedSize30dMB, ProjectedSize90dMB, DaysUntilFull, ForecastMethod)
    VALUES
        (DB_NAME(), @CurrentTotal, @CurrentUsed, @AvgDaily, @Proj30, @Proj90, @DaysUntilFull, @Method);

    /* Also store in metric snapshot for trending */
    INSERT INTO dbo.DatabaseMetricSnapshot (MetricCategory, MetricName, MetricValue, MetricUnit)
    VALUES
        (N'Forecast', N'AvgDailyGrowthMB', @AvgDaily, N'MB'),
        (N'Forecast', N'DaysUntilFull', ISNULL(@DaysUntilFull, -1), N'Days'),
        (N'Forecast', N'ProjectedUsed30dMB', @Proj30, N'MB'),
        (N'Forecast', N'ProjectedUsed90dMB', @Proj90, N'MB');

    SELECT TOP (1)
        ForecastId, DatabaseName, CurrentSizeMB, UsedSpaceMB, AvgDailyGrowthMB,
        ProjectedSize30dMB, ProjectedSize90dMB, DaysUntilFull, ForecastMethod, CapturedAt
    FROM dbo.CapacityForecastCache
    ORDER BY ForecastId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Cap_CaptureMetricSnapshot
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunId INT;
    DECLARE @TotalMB DECIMAL(18,4);
    DECLARE @UsedMB DECIMAL(18,4);
    DECLARE @UsedPct DECIMAL(18,4);
    DECLARE @ErrMsg NVARCHAR(4000);
    DECLARE @Details NVARCHAR(200);

    EXEC dbo.sp_CapPerf_LogStart N'ELM_CapPerf_CollectMetrics', N'CaptureSnapshot', @RunId OUTPUT;

    BEGIN TRY
        IF OBJECT_ID(N'dbo.sp_Monitor_CaptureMetricSnapshot', N'P') IS NOT NULL
            EXEC dbo.sp_Monitor_CaptureMetricSnapshot;
        ELSE
        BEGIN
            SELECT
                @TotalMB = SUM(size) * 8.0 / 1024,
                @UsedMB = SUM(FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024
            FROM sys.database_files;
            SET @UsedPct = CASE WHEN @TotalMB = 0 THEN 0 ELSE @UsedMB * 100.0 / @TotalMB END;

            INSERT INTO dbo.DatabaseMetricSnapshot (MetricCategory, MetricName, MetricValue, MetricUnit)
            VALUES
                (N'Size', N'TotalSizeMB', @TotalMB, N'MB'),
                (N'Size', N'UsedSpaceMB', @UsedMB, N'MB'),
                (N'Size', N'UsedPercent', @UsedPct, N'Percent');
        END

        /* Volume free space */
        INSERT INTO dbo.DatabaseMetricSnapshot (MetricCategory, MetricName, MetricValue, MetricUnit)
        SELECT DISTINCT
            N'Volume',
            N'FreePercent_' + REPLACE(REPLACE(vs.volume_mount_point, N'\', N'_'), N':', N''),
            CAST(vs.available_bytes * 100.0 / NULLIF(vs.total_bytes, 0) AS DECIMAL(18,4)),
            N'Percent'
        FROM sys.master_files mf
        CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs
        WHERE mf.database_id = DB_ID();

        EXEC dbo.sp_Cap_ForecastCapacity @LookbackDays = 90;

        SET @Details = N'Metrics and forecast captured.';
        EXEC dbo.sp_CapPerf_LogEnd @RunId = @RunId, @Status = N'Success', @Details = @Details;
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        EXEC dbo.sp_CapPerf_LogEnd @RunId = @RunId, @Status = N'Failed', @ErrorMessage = @ErrMsg;
        THROW;
    END CATCH
END
GO

PRINT '02_Capacity_Monitoring_Procedures completed.';
GO
