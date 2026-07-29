/*
================================================================================
  Data Validation Framework Procedures
  Database: EmployeeLeaveDb
================================================================================
*/
USE EmployeeLeaveDb;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Val_LogIssue
    @RunId INT = NULL,
    @CheckCode NVARCHAR(50),
    @Severity NVARCHAR(20),
    @EntityName NVARCHAR(128),
    @EntityKey NVARCHAR(100) = NULL,
    @ValidationDetail NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.DataValidationLog (RunId, CheckCode, Severity, EntityName, EntityKey, ValidationDetail)
    VALUES (@RunId, @CheckCode, @Severity, @EntityName, @EntityKey, @ValidationDetail);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Val_CheckInvalidLeaveBalances
    @RunId INT = NULL,
    @BalanceYear INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @BalanceYear IS NULL SET @BalanceYear = YEAR(SYSUTCDATETIME());
    IF OBJECT_ID(N'dbo.LeaveBalances', N'U') IS NULL
    BEGIN
        SELECT 0 AS IssueCount;
        RETURN;
    END

    DECLARE @Count INT = 0;

    INSERT INTO dbo.DataValidationLog (RunId, CheckCode, Severity, EntityName, EntityKey, ValidationDetail)
    SELECT @RunId, N'INVALID_BALANCE', N'High', N'LeaveBalances', CAST(lb.LeaveBalanceId AS NVARCHAR(20)),
           CONCAT(N'Negative RemainingDays or UsedDays>EntitledDays for EmployeeId=', lb.EmployeeId,
                  N' LeaveTypeId=', lb.LeaveTypeId, N' Year=', lb.BalanceYear)
    FROM dbo.LeaveBalances lb
    WHERE lb.BalanceYear = @BalanceYear
      AND lb.IsHistorical = 0
      AND (lb.UsedDays < 0 OR lb.EntitledDays < 0 OR lb.UsedDays > lb.EntitledDays);
    SET @Count += @@ROWCOUNT;

    ;WITH Approved AS (
        SELECT EmployeeId, LeaveTypeId, YEAR(StartDate) AS Yr, SUM(CAST(TotalDays AS DECIMAL(9,2))) AS Days
        FROM dbo.LeaveRequests
        WHERE Status = N'Approved' AND IsCancelled = 0 AND YEAR(StartDate) = @BalanceYear
        GROUP BY EmployeeId, LeaveTypeId, YEAR(StartDate)
    )
    INSERT INTO dbo.DataValidationLog (RunId, CheckCode, Severity, EntityName, EntityKey, ValidationDetail)
    SELECT @RunId, N'BALANCE_MISMATCH', N'High', N'LeaveBalances', CAST(lb.LeaveBalanceId AS NVARCHAR(20)),
           CONCAT(N'UsedDays=', lb.UsedDays, N' vs approved=', ISNULL(a.Days, 0))
    FROM dbo.LeaveBalances lb
    LEFT JOIN Approved a ON a.EmployeeId = lb.EmployeeId AND a.LeaveTypeId = lb.LeaveTypeId AND a.Yr = lb.BalanceYear
    WHERE lb.BalanceYear = @BalanceYear AND lb.IsHistorical = 0
      AND ISNULL(lb.UsedDays, 0) <> ISNULL(a.Days, 0);
    SET @Count += @@ROWCOUNT;

    SELECT @Count AS IssueCount;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Val_CheckMissingMandatoryRecords
    @RunId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Count INT = 0;

    IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleName = N'Admin' AND IsActive = 1)
    BEGIN
        EXEC dbo.sp_Val_LogIssue @RunId, N'MISSING_MANDATORY', N'Critical', N'Roles', N'Admin',
            N'Active Admin role is missing.';
        SET @Count += 1;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.Users u INNER JOIN dbo.Roles r ON u.RoleId = r.RoleId WHERE r.RoleName = N'Admin' AND u.IsActive = 1)
    BEGIN
        EXEC dbo.sp_Val_LogIssue @RunId, N'MISSING_MANDATORY', N'Critical', N'Users', N'AdminUser',
            N'No active Admin user found.';
        SET @Count += 1;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.LeaveTypes WHERE IsActive = 1)
    BEGIN
        EXEC dbo.sp_Val_LogIssue @RunId, N'MISSING_MANDATORY', N'Critical', N'LeaveTypes', NULL,
            N'No active leave types configured.';
        SET @Count += 1;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.Departments WHERE IsActive = 1)
    BEGIN
        EXEC dbo.sp_Val_LogIssue @RunId, N'MISSING_MANDATORY', N'High', N'Departments', NULL,
            N'No active departments configured.';
        SET @Count += 1;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.Meta_LookupValue WHERE CategoryCode = N'LEAVE_STATUS' AND LookupCode = N'Pending' AND IsActive = 1)
    BEGIN
        EXEC dbo.sp_Val_LogIssue @RunId, N'MISSING_MANDATORY', N'Medium', N'Meta_LookupValue', N'LEAVE_STATUS/Pending',
            N'Required leave status lookup Pending is missing.';
        SET @Count += 1;
    END

    SELECT @Count AS IssueCount;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Val_CheckDuplicateMasterData
    @RunId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Count INT = 0;

    INSERT INTO dbo.DataValidationLog (RunId, CheckCode, Severity, EntityName, EntityKey, ValidationDetail)
    SELECT @RunId, N'DUPLICATE_MASTER', N'High', N'Departments', MIN(CAST(DepartmentId AS NVARCHAR(20))),
           CONCAT(N'Duplicate DepartmentName=', DepartmentName, N' count=', COUNT(*))
    FROM dbo.Departments
    GROUP BY DepartmentName
    HAVING COUNT(*) > 1;
    SET @Count += @@ROWCOUNT;

    INSERT INTO dbo.DataValidationLog (RunId, CheckCode, Severity, EntityName, EntityKey, ValidationDetail)
    SELECT @RunId, N'DUPLICATE_MASTER', N'High', N'Departments', MIN(CAST(DepartmentId AS NVARCHAR(20))),
           CONCAT(N'Duplicate DepartmentCode=', DepartmentCode, N' count=', COUNT(*))
    FROM dbo.Departments
    WHERE DepartmentCode IS NOT NULL
    GROUP BY DepartmentCode
    HAVING COUNT(*) > 1;
    SET @Count += @@ROWCOUNT;

    INSERT INTO dbo.DataValidationLog (RunId, CheckCode, Severity, EntityName, EntityKey, ValidationDetail)
    SELECT @RunId, N'DUPLICATE_MASTER', N'High', N'LeaveTypes', MIN(CAST(LeaveTypeId AS NVARCHAR(20))),
           CONCAT(N'Duplicate LeaveTypeName=', LeaveTypeName, N' count=', COUNT(*))
    FROM dbo.LeaveTypes
    GROUP BY LeaveTypeName
    HAVING COUNT(*) > 1;
    SET @Count += @@ROWCOUNT;

    INSERT INTO dbo.DataValidationLog (RunId, CheckCode, Severity, EntityName, EntityKey, ValidationDetail)
    SELECT @RunId, N'DUPLICATE_MASTER', N'Critical', N'Roles', MIN(CAST(RoleId AS NVARCHAR(20))),
           CONCAT(N'Duplicate RoleName=', RoleName, N' count=', COUNT(*))
    FROM dbo.Roles
    GROUP BY RoleName
    HAVING COUNT(*) > 1;
    SET @Count += @@ROWCOUNT;

    INSERT INTO dbo.DataValidationLog (RunId, CheckCode, Severity, EntityName, EntityKey, ValidationDetail)
    SELECT @RunId, N'DUPLICATE_MASTER', N'Critical', N'Employees', MIN(CAST(EmployeeId AS NVARCHAR(20))),
           CONCAT(N'Duplicate EmployeeCode=', EmployeeCode, N' count=', COUNT(*))
    FROM dbo.Employees
    GROUP BY EmployeeCode
    HAVING COUNT(*) > 1;
    SET @Count += @@ROWCOUNT;

    INSERT INTO dbo.DataValidationLog (RunId, CheckCode, Severity, EntityName, EntityKey, ValidationDetail)
    SELECT @RunId, N'DUPLICATE_MASTER', N'Critical', N'Users', MIN(CAST(UserId AS NVARCHAR(20))),
           CONCAT(N'Duplicate UserName=', UserName, N' count=', COUNT(*))
    FROM dbo.Users
    GROUP BY UserName
    HAVING COUNT(*) > 1;
    SET @Count += @@ROWCOUNT;

    SELECT @Count AS IssueCount;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Val_CheckInvalidReferenceData
    @RunId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Count INT = 0;

    INSERT INTO dbo.DataValidationLog (RunId, CheckCode, Severity, EntityName, EntityKey, ValidationDetail)
    SELECT @RunId, N'INVALID_REFERENCE', N'Medium', N'LeaveRequests', CAST(lr.LeaveRequestId AS NVARCHAR(20)),
           CONCAT(N'Status ''', lr.Status, N''' is not in Meta_LookupValue LEAVE_STATUS')
    FROM dbo.LeaveRequests lr
    WHERE lr.IsCancelled = 0
      AND NOT EXISTS (
          SELECT 1 FROM dbo.Meta_LookupValue v
          WHERE v.CategoryCode = N'LEAVE_STATUS' AND v.LookupCode = lr.Status AND v.IsActive = 1);
    SET @Count += @@ROWCOUNT;

    INSERT INTO dbo.DataValidationLog (RunId, CheckCode, Severity, EntityName, EntityKey, ValidationDetail)
    SELECT @RunId, N'INVALID_REFERENCE', N'Medium', N'Meta_ConfigCategory', c.CategoryCode,
           CONCAT(N'ModuleCode ''', c.ModuleCode, N''' does not exist in Meta_ApplicationModule')
    FROM dbo.Meta_ConfigCategory c
    WHERE c.ModuleCode IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.Meta_ApplicationModule m WHERE m.ModuleCode = c.ModuleCode);
    SET @Count += @@ROWCOUNT;

    SELECT @Count AS IssueCount;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Val_CheckOrphanRecords
    @RunId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Count INT = 0;

    INSERT INTO dbo.DataValidationLog (RunId, CheckCode, Severity, EntityName, EntityKey, ValidationDetail)
    SELECT @RunId, N'ORPHAN_RECORD', N'Critical', N'LeaveRequests', CAST(lr.LeaveRequestId AS NVARCHAR(20)),
           CONCAT(N'Orphan EmployeeId=', lr.EmployeeId)
    FROM dbo.LeaveRequests lr
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Employees e WHERE e.EmployeeId = lr.EmployeeId);
    SET @Count += @@ROWCOUNT;

    INSERT INTO dbo.DataValidationLog (RunId, CheckCode, Severity, EntityName, EntityKey, ValidationDetail)
    SELECT @RunId, N'ORPHAN_RECORD', N'Critical', N'LeaveRequests', CAST(lr.LeaveRequestId AS NVARCHAR(20)),
           CONCAT(N'Orphan LeaveTypeId=', lr.LeaveTypeId)
    FROM dbo.LeaveRequests lr
    WHERE NOT EXISTS (SELECT 1 FROM dbo.LeaveTypes lt WHERE lt.LeaveTypeId = lr.LeaveTypeId);
    SET @Count += @@ROWCOUNT;

    INSERT INTO dbo.DataValidationLog (RunId, CheckCode, Severity, EntityName, EntityKey, ValidationDetail)
    SELECT @RunId, N'ORPHAN_RECORD', N'Critical', N'Users', CAST(u.UserId AS NVARCHAR(20)),
           CONCAT(N'Orphan RoleId=', u.RoleId)
    FROM dbo.Users u
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Roles r WHERE r.RoleId = u.RoleId);
    SET @Count += @@ROWCOUNT;

    INSERT INTO dbo.DataValidationLog (RunId, CheckCode, Severity, EntityName, EntityKey, ValidationDetail)
    SELECT @RunId, N'ORPHAN_RECORD', N'High', N'Employees', CAST(e.EmployeeId AS NVARCHAR(20)),
           CONCAT(N'Orphan DepartmentId=', e.DepartmentId)
    FROM dbo.Employees e
    WHERE e.DepartmentId IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.Departments d WHERE d.DepartmentId = e.DepartmentId);
    SET @Count += @@ROWCOUNT;

    INSERT INTO dbo.DataValidationLog (RunId, CheckCode, Severity, EntityName, EntityKey, ValidationDetail)
    SELECT @RunId, N'ORPHAN_RECORD', N'Medium', N'Employees', CAST(e.EmployeeId AS NVARCHAR(20)),
           CONCAT(N'Orphan ManagerId=', e.ManagerId)
    FROM dbo.Employees e
    WHERE e.ManagerId IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.Employees m WHERE m.EmployeeId = e.ManagerId);
    SET @Count += @@ROWCOUNT;

    SELECT @Count AS IssueCount;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Val_RunAllChecks
    @BalanceYear INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunId INT, @Total INT = 0, @Checks INT = 5, @Status NVARCHAR(20), @Details NVARCHAR(300);

    INSERT INTO dbo.DataValidationRunLog (JobName, Status)
    VALUES (N'ELM_Mig_Validation_Checks', N'Running');
    SET @RunId = SCOPE_IDENTITY();

    BEGIN TRY
        EXEC dbo.sp_Val_CheckInvalidLeaveBalances @RunId = @RunId, @BalanceYear = @BalanceYear;
        EXEC dbo.sp_Val_CheckMissingMandatoryRecords @RunId = @RunId;
        EXEC dbo.sp_Val_CheckDuplicateMasterData @RunId = @RunId;
        EXEC dbo.sp_Val_CheckInvalidReferenceData @RunId = @RunId;
        EXEC dbo.sp_Val_CheckOrphanRecords @RunId = @RunId;

        SELECT @Total = COUNT(*) FROM dbo.DataValidationLog WHERE RunId = @RunId;
        SET @Status = CASE WHEN @Total = 0 THEN N'Success' ELSE N'Warning' END;
        SET @Details = CONCAT(N'Validation completed. Issues=', @Total);

        UPDATE dbo.DataValidationRunLog
        SET EndTime = SYSUTCDATETIME(), Status = @Status, ChecksRun = @Checks,
            IssuesFound = @Total, Details = @Details
        WHERE RunId = @RunId;

        SELECT @RunId AS RunId, @Checks AS ChecksRun, @Total AS IssuesFound, @Status AS Status;
    END TRY
    BEGIN CATCH
        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        UPDATE dbo.DataValidationRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Failed', ErrorMessage = @Err
        WHERE RunId = @RunId;
        THROW;
    END CATCH
END
GO

PRINT '04_Validation_Procedures completed.';
GO
