/*
================================================================================
  Compliance Reporting Procedures
  Database: EmployeeLeaveDb
================================================================================
*/
USE EmployeeLeaveDb;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_IntegrityViolations
    @DaysBack INT = 30,
    @UnresolvedOnly BIT = 0,
    @Severity NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        v.ViolationId,
        v.RunId,
        v.CheckCode,
        v.Severity,
        v.EntityName,
        v.EntityId,
        v.EmployeeId,
        v.ViolationDetail,
        v.DetectedAt,
        v.IsResolved,
        v.ResolvedAt,
        v.ResolvedBy,
        v.ResolutionNotes
    FROM dbo.IntegrityViolationLog v
    WHERE v.DetectedAt >= DATEADD(DAY, -@DaysBack, SYSUTCDATETIME())
      AND (@UnresolvedOnly = 0 OR v.IsResolved = 0)
      AND (@Severity IS NULL OR v.Severity = @Severity)
    ORDER BY
        CASE v.Severity
            WHEN N'Critical' THEN 1
            WHEN N'High' THEN 2
            WHEN N'Medium' THEN 3
            ELSE 4
        END,
        v.DetectedAt DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_AuditSummary
    @DaysBack INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        a.TableName,
        a.ActionType,
        COUNT(*) AS EventCount,
        COUNT(DISTINCT a.ChangedBy) AS DistinctActors,
        MIN(a.ChangedOn) AS FirstEventAt,
        MAX(a.ChangedOn) AS LastEventAt
    FROM dbo.AuditLogs a
    WHERE a.ChangedOn >= DATEADD(DAY, -@DaysBack, SYSUTCDATETIME())
    GROUP BY a.TableName, a.ActionType
    ORDER BY a.TableName, a.ActionType;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_DataQualityStatus
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OpenCritical INT =
        (SELECT COUNT(*) FROM dbo.IntegrityViolationLog WHERE IsResolved = 0 AND Severity = N'Critical');
    DECLARE @OpenHigh INT =
        (SELECT COUNT(*) FROM dbo.IntegrityViolationLog WHERE IsResolved = 0 AND Severity = N'High');
    DECLARE @OpenMedium INT =
        (SELECT COUNT(*) FROM dbo.IntegrityViolationLog WHERE IsResolved = 0 AND Severity = N'Medium');
    DECLARE @OpenLow INT =
        (SELECT COUNT(*) FROM dbo.IntegrityViolationLog WHERE IsResolved = 0 AND Severity = N'Low');
    DECLARE @AuditEvents7d INT =
        (SELECT COUNT(*) FROM dbo.AuditLogs WHERE ChangedOn >= DATEADD(DAY, -7, SYSUTCDATETIME()));
    DECLARE @ActivityEvents7d INT =
        (SELECT COUNT(*) FROM dbo.UserActivityLog WHERE ActivityAt >= DATEADD(DAY, -7, SYSUTCDATETIME()));
    DECLARE @Exceptions7d INT =
        (SELECT COUNT(*) FROM dbo.DatabaseExceptionLog WHERE CapturedAt >= DATEADD(DAY, -7, SYSUTCDATETIME()));
    DECLARE @LastRunStatus NVARCHAR(20) =
        (SELECT TOP 1 Status FROM dbo.ComplianceRunLog ORDER BY RunId DESC);
    DECLARE @LastRunAt DATETIME2 =
        (SELECT TOP 1 StartTime FROM dbo.ComplianceRunLog ORDER BY RunId DESC);

    SELECT
        CASE
            WHEN @OpenCritical > 0 THEN N'Critical'
            WHEN @OpenHigh > 0 THEN N'AtRisk'
            WHEN @OpenMedium > 0 THEN N'Watch'
            ELSE N'Healthy'
        END AS DataQualityStatus,
        @OpenCritical AS OpenCritical,
        @OpenHigh AS OpenHigh,
        @OpenMedium AS OpenMedium,
        @OpenLow AS OpenLow,
        @AuditEvents7d AS AuditEventsLast7Days,
        @ActivityEvents7d AS UserActivityLast7Days,
        @Exceptions7d AS ExceptionsLast7Days,
        @LastRunStatus AS LastComplianceRunStatus,
        @LastRunAt AS LastComplianceRunAt,
        (SELECT COUNT(*) FROM dbo.Holidays WHERE IsActive = 1) AS ActiveHolidays,
        (SELECT COUNT(*) FROM dbo.LeavePolicies WHERE IsActive = 1) AS ActivePolicies,
        SYSUTCDATETIME() AS CapturedAtUtc;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_UserActivitySummary
    @DaysBack INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ISNULL(a.UserName, N'(unknown)') AS UserName,
        a.ActivityType,
        COUNT(*) AS ActivityCount,
        SUM(CASE WHEN a.Success = 1 THEN 1 ELSE 0 END) AS SuccessCount,
        SUM(CASE WHEN a.Success = 0 THEN 1 ELSE 0 END) AS FailureCount,
        MIN(a.ActivityAt) AS FirstActivityAt,
        MAX(a.ActivityAt) AS LastActivityAt
    FROM dbo.UserActivityLog a
    WHERE a.ActivityAt >= DATEADD(DAY, -@DaysBack, SYSUTCDATETIME())
    GROUP BY ISNULL(a.UserName, N'(unknown)'), a.ActivityType
    ORDER BY ActivityCount DESC, UserName, ActivityType;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Compliance_ResolveViolation
    @ViolationId BIGINT,
    @ResolvedBy NVARCHAR(100),
    @ResolutionNotes NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.IntegrityViolationLog
    SET IsResolved = 1,
        ResolvedAt = SYSUTCDATETIME(),
        ResolvedBy = @ResolvedBy,
        ResolutionNotes = @ResolutionNotes
    WHERE ViolationId = @ViolationId
      AND IsResolved = 0;

    IF @@ROWCOUNT = 0
        THROW 50010, 'Violation not found or already resolved.', 1;

    SELECT * FROM dbo.IntegrityViolationLog WHERE ViolationId = @ViolationId;
END
GO

PRINT '04_Compliance_Report_Procedures completed.';
GO
