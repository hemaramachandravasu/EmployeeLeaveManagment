/*
================================================================================
  Compliance Monitoring Procedures
  Database: EmployeeLeaveDb
================================================================================
*/
USE EmployeeLeaveDb;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_FailedValidationChecks
    @HoursBack INT = 48
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        r.RunId,
        r.JobName,
        r.StepName,
        r.StartTime,
        r.EndTime,
        r.Status,
        r.ChecksRun,
        r.ViolationsFound,
        r.Details,
        r.ErrorMessage
    FROM dbo.ComplianceRunLog r
    WHERE r.StartTime >= DATEADD(HOUR, -@HoursBack, SYSUTCDATETIME())
      AND r.Status IN (N'Failed', N'Warning')
    ORDER BY r.StartTime DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_DatabaseExceptions
    @HoursBack INT = 48
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        e.ExceptionId,
        e.SourceProc,
        e.ErrorNumber,
        e.ErrorSeverity,
        e.ErrorState,
        e.ErrorMessage,
        e.CapturedAt,
        e.ContextInfo
    FROM dbo.DatabaseExceptionLog e
    WHERE e.CapturedAt >= DATEADD(HOUR, -@HoursBack, SYSUTCDATETIME())
    ORDER BY e.CapturedAt DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_ScheduledAuditJobs
    @HoursBack INT = 72
AS
BEGIN
    SET NOCOUNT ON;

    /* Prefer msdb Agent history for ELM_Compliance_* / ELM_Audit_* jobs when available */
    IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'msdb')
    BEGIN
        SELECT
            j.name AS JobName,
            h.step_id AS StepId,
            h.step_name AS StepName,
            msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunDateTime,
            CASE h.run_status
                WHEN 0 THEN N'Failed'
                WHEN 1 THEN N'Succeeded'
                WHEN 2 THEN N'Retry'
                WHEN 3 THEN N'Canceled'
                ELSE N'Unknown'
            END AS RunStatus,
            h.message AS Message
        FROM msdb.dbo.sysjobhistory h
        INNER JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
        WHERE j.name LIKE N'ELM_Compliance_%'
           OR j.name LIKE N'ELM_Audit_%'
        ORDER BY h.run_date DESC, h.run_time DESC;
    END

    /* Always also return ComplianceRunLog snapshot */
    SELECT
        r.RunId,
        r.JobName,
        r.StepName,
        r.StartTime,
        r.EndTime,
        r.Status,
        r.ChecksRun,
        r.ViolationsFound,
        r.Details
    FROM dbo.ComplianceRunLog r
    WHERE r.StartTime >= DATEADD(HOUR, -@HoursBack, SYSUTCDATETIME())
    ORDER BY r.StartTime DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Monitor_ComplianceStatus
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OpenViolations INT =
        (SELECT COUNT(*) FROM dbo.IntegrityViolationLog WHERE IsResolved = 0);
    DECLARE @CriticalOpen INT =
        (SELECT COUNT(*) FROM dbo.IntegrityViolationLog WHERE IsResolved = 0 AND Severity = N'Critical');
    DECLARE @FailedRuns24h INT =
        (SELECT COUNT(*) FROM dbo.ComplianceRunLog
         WHERE StartTime >= DATEADD(HOUR, -24, SYSUTCDATETIME()) AND Status = N'Failed');
    DECLARE @Exceptions24h INT =
        (SELECT COUNT(*) FROM dbo.DatabaseExceptionLog
         WHERE CapturedAt >= DATEADD(HOUR, -24, SYSUTCDATETIME()));
    DECLARE @LastSuccessAt DATETIME2 =
        (SELECT MAX(EndTime) FROM dbo.ComplianceRunLog WHERE Status IN (N'Success', N'Warning'));

    SELECT
        CASE
            WHEN @CriticalOpen > 0 OR @FailedRuns24h > 0 THEN N'NonCompliant'
            WHEN @OpenViolations > 0 OR @Exceptions24h > 0 THEN N'AttentionRequired'
            ELSE N'Compliant'
        END AS ComplianceStatus,
        @OpenViolations AS OpenViolations,
        @CriticalOpen AS OpenCriticalViolations,
        @FailedRuns24h AS FailedRunsLast24h,
        @Exceptions24h AS ExceptionsLast24h,
        @LastSuccessAt AS LastSuccessfulCheckAt,
        (SELECT COUNT(*) FROM dbo.AuditLogs WHERE ChangedOn >= DATEADD(DAY, -1, SYSUTCDATETIME())) AS AuditEventsLast24h,
        (SELECT COUNT(*) FROM dbo.UserActivityLog WHERE ActivityAt >= DATEADD(DAY, -1, SYSUTCDATETIME())) AS UserActivityLast24h,
        SYSUTCDATETIME() AS CapturedAtUtc;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Compliance_RunScheduledAuditJob
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Integrity_RunAllChecks;
    EXEC dbo.sp_Monitor_ComplianceStatus;
END
GO

PRINT '05_Monitoring_Procedures completed.';
GO
