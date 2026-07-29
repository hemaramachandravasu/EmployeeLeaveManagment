/*
================================================================================
  Migration / Validation / Metadata Reports
  Database: EmployeeLeaveDb
================================================================================
*/
USE EmployeeLeaveDb;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_MigrationHistory
    @TopN INT = 100,
    @Status NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Mig_GetHistory @Status = @Status, @TopN = @TopN;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_ValidationSummary
    @DaysBack INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CheckCode,
        Severity,
        COUNT(*) AS IssueCount,
        SUM(CASE WHEN IsResolved = 0 THEN 1 ELSE 0 END) AS OpenCount,
        MIN(DetectedAt) AS FirstDetectedAt,
        MAX(DetectedAt) AS LastDetectedAt
    FROM dbo.DataValidationLog
    WHERE DetectedAt >= DATEADD(DAY, -@DaysBack, SYSUTCDATETIME())
    GROUP BY CheckCode, Severity
    ORDER BY
        CASE Severity WHEN N'Critical' THEN 1 WHEN N'High' THEN 2 WHEN N'Medium' THEN 3 ELSE 4 END,
        IssueCount DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_ValidationIssues
    @DaysBack INT = 30,
    @UnresolvedOnly BIT = 0,
    @CheckCode NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ValidationId, RunId, CheckCode, Severity, EntityName, EntityKey,
        ValidationDetail, DetectedAt, IsResolved, ResolvedAt, ResolvedBy
    FROM dbo.DataValidationLog
    WHERE DetectedAt >= DATEADD(DAY, -@DaysBack, SYSUTCDATETIME())
      AND (@UnresolvedOnly = 0 OR IsResolved = 0)
      AND (@CheckCode IS NULL OR CheckCode = @CheckCode)
    ORDER BY DetectedAt DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_DataQualityDashboard
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OpenCritical INT = (SELECT COUNT(*) FROM dbo.DataValidationLog WHERE IsResolved = 0 AND Severity = N'Critical');
    DECLARE @OpenHigh INT = (SELECT COUNT(*) FROM dbo.DataValidationLog WHERE IsResolved = 0 AND Severity = N'High');
    DECLARE @OpenMedium INT = (SELECT COUNT(*) FROM dbo.DataValidationLog WHERE IsResolved = 0 AND Severity = N'Medium');
    DECLARE @OpenLow INT = (SELECT COUNT(*) FROM dbo.DataValidationLog WHERE IsResolved = 0 AND Severity = N'Low');
    DECLARE @AppliedMigs INT = (SELECT COUNT(*) FROM dbo.SchemaMigrationHistory WHERE Status = N'Applied');
    DECLARE @FailedMigs INT = (SELECT COUNT(*) FROM dbo.SchemaMigrationHistory WHERE Status = N'Failed');
    DECLARE @LastValStatus NVARCHAR(20) = (SELECT TOP 1 Status FROM dbo.DataValidationRunLog ORDER BY RunId DESC);
    DECLARE @LastValAt DATETIME2 = (SELECT TOP 1 StartTime FROM dbo.DataValidationRunLog ORDER BY RunId DESC);

    SELECT
        CASE
            WHEN @OpenCritical > 0 OR @FailedMigs > 0 THEN N'Critical'
            WHEN @OpenHigh > 0 THEN N'AtRisk'
            WHEN @OpenMedium > 0 THEN N'Watch'
            ELSE N'Healthy'
        END AS DataQualityStatus,
        @OpenCritical AS OpenCritical,
        @OpenHigh AS OpenHigh,
        @OpenMedium AS OpenMedium,
        @OpenLow AS OpenLow,
        @AppliedMigs AS AppliedMigrations,
        @FailedMigs AS FailedMigrations,
        @LastValStatus AS LastValidationStatus,
        @LastValAt AS LastValidationAt,
        (SELECT COUNT(*) FROM dbo.Meta_LookupValue WHERE IsActive = 1) AS ActiveLookups,
        (SELECT COUNT(*) FROM dbo.Meta_ApplicationModule WHERE IsActive = 1) AS ActiveModules,
        SYSUTCDATETIME() AS CapturedAtUtc;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Val_ResolveIssue
    @ValidationId BIGINT,
    @ResolvedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.DataValidationLog
    SET IsResolved = 1, ResolvedAt = SYSUTCDATETIME(), ResolvedBy = @ResolvedBy
    WHERE ValidationId = @ValidationId AND IsResolved = 0;

    IF @@ROWCOUNT = 0
        THROW 51010, 'Validation issue not found or already resolved.', 1;

    SELECT * FROM dbo.DataValidationLog WHERE ValidationId = @ValidationId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Val_ArchiveHistoricalLogs
    @RetainDays INT = 120
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunId INT;
    EXEC dbo.sp_Mig_LogRunStart N'Validate', NULL, @RunId OUTPUT;

    BEGIN TRY
        DELETE FROM dbo.DataValidationLog
        WHERE IsResolved = 1
          AND DetectedAt < DATEADD(DAY, -@RetainDays, SYSUTCDATETIME());
        DECLARE @V INT = @@ROWCOUNT;

        DELETE FROM dbo.DataValidationRunLog
        WHERE EndTime IS NOT NULL
          AND StartTime < DATEADD(DAY, -@RetainDays, SYSUTCDATETIME());
        DECLARE @R INT = @@ROWCOUNT;

        DECLARE @Details NVARCHAR(200) = CONCAT(N'Archived validation issues=', @V, N' runs=', @R);
        EXEC dbo.sp_Mig_LogRunEnd @RunId, N'Success', @Details;
    END TRY
    BEGIN CATCH
        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        EXEC dbo.sp_Mig_LogRunEnd @RunId, N'Failed', NULL, @Err;
        THROW;
    END CATCH
END
GO

PRINT '05_Report_Procedures completed.';
GO
