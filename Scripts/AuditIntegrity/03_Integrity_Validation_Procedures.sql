/*
================================================================================
  Data Integrity Validation Procedures
  Database: EmployeeLeaveDb

  Checks:
    • Leave balance consistency (UsedDays vs approved leave)
    • Duplicate / overlapping leave requests
    • Orphan / invalid foreign key references
    • Holiday mapping (leave spanning holidays with ExcludeHolidays policy)
    • Policy violations (max consecutive days, notice, yearly request caps)
================================================================================
*/
USE EmployeeLeaveDb;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Compliance_LogStart
    @JobName  NVARCHAR(128),
    @StepName NVARCHAR(128),
    @RunId    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.ComplianceRunLog (JobName, StepName, Status)
    VALUES (@JobName, @StepName, N'Running');
    SET @RunId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Compliance_LogEnd
    @RunId            INT,
    @Status           NVARCHAR(20),
    @ChecksRun        INT = NULL,
    @ViolationsFound  INT = NULL,
    @Details          NVARCHAR(MAX) = NULL,
    @ErrorMessage     NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.ComplianceRunLog
    SET EndTime = SYSUTCDATETIME(),
        Status = @Status,
        ChecksRun = @ChecksRun,
        ViolationsFound = @ViolationsFound,
        Details = @Details,
        ErrorMessage = @ErrorMessage
    WHERE RunId = @RunId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Integrity_RecordViolation
    @RunId           INT = NULL,
    @CheckCode       NVARCHAR(50),
    @Severity        NVARCHAR(20),
    @EntityName      NVARCHAR(128),
    @EntityId        INT = NULL,
    @EmployeeId      INT = NULL,
    @ViolationDetail NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.IntegrityViolationLog
        (RunId, CheckCode, Severity, EntityName, EntityId, EmployeeId, ViolationDetail)
    VALUES
        (@RunId, @CheckCode, @Severity, @EntityName, @EntityId, @EmployeeId, @ViolationDetail);
END
GO

/* ---------- 1) Leave balance consistency ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Integrity_CheckLeaveBalanceConsistency
    @RunId INT = NULL,
    @BalanceYear INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @BalanceYear IS NULL SET @BalanceYear = YEAR(SYSUTCDATETIME());
    IF OBJECT_ID(N'dbo.LeaveBalances', N'U') IS NULL
    BEGIN
        SELECT CAST(0 AS INT) AS ViolationCount;
        RETURN;
    END

    DECLARE @Count INT = 0;

    ;WITH ApprovedUsage AS (
        SELECT
            lr.EmployeeId,
            lr.LeaveTypeId,
            YEAR(lr.StartDate) AS BalanceYear,
            SUM(CAST(lr.TotalDays AS DECIMAL(9,2))) AS ApprovedDays
        FROM dbo.LeaveRequests lr
        WHERE lr.Status = N'Approved'
          AND lr.IsCancelled = 0
          AND YEAR(lr.StartDate) = @BalanceYear
        GROUP BY lr.EmployeeId, lr.LeaveTypeId, YEAR(lr.StartDate)
    )
    INSERT INTO dbo.IntegrityViolationLog
        (RunId, CheckCode, Severity, EntityName, EntityId, EmployeeId, ViolationDetail)
    SELECT
        @RunId,
        N'BALANCE_MISMATCH',
        N'High',
        N'LeaveBalances',
        lb.LeaveBalanceId,
        lb.EmployeeId,
        CONCAT(N'UsedDays=', lb.UsedDays, N' but approved leave days=', ISNULL(au.ApprovedDays, 0),
               N' for EmployeeId=', lb.EmployeeId, N' LeaveTypeId=', lb.LeaveTypeId, N' Year=', lb.BalanceYear)
    FROM dbo.LeaveBalances lb
    LEFT JOIN ApprovedUsage au
        ON au.EmployeeId = lb.EmployeeId
       AND au.LeaveTypeId = lb.LeaveTypeId
       AND au.BalanceYear = lb.BalanceYear
    WHERE lb.BalanceYear = @BalanceYear
      AND lb.IsHistorical = 0
      AND ISNULL(lb.UsedDays, 0) <> ISNULL(au.ApprovedDays, 0);

    SET @Count = @@ROWCOUNT;

    /* Also flag approved leave with no balance row */
    INSERT INTO dbo.IntegrityViolationLog
        (RunId, CheckCode, Severity, EntityName, EntityId, EmployeeId, ViolationDetail)
    SELECT
        @RunId,
        N'BALANCE_MISSING',
        N'Medium',
        N'LeaveRequests',
        MIN(lr.LeaveRequestId),
        lr.EmployeeId,
        CONCAT(N'Approved leave exists without LeaveBalances row for EmployeeId=', lr.EmployeeId,
               N' LeaveTypeId=', lr.LeaveTypeId, N' Year=', YEAR(lr.StartDate))
    FROM dbo.LeaveRequests lr
    WHERE lr.Status = N'Approved'
      AND lr.IsCancelled = 0
      AND YEAR(lr.StartDate) = @BalanceYear
      AND NOT EXISTS (
          SELECT 1 FROM dbo.LeaveBalances lb
          WHERE lb.EmployeeId = lr.EmployeeId
            AND lb.LeaveTypeId = lr.LeaveTypeId
            AND lb.BalanceYear = YEAR(lr.StartDate)
            AND lb.IsHistorical = 0)
    GROUP BY lr.EmployeeId, lr.LeaveTypeId, YEAR(lr.StartDate);

    SET @Count += @@ROWCOUNT;
    SELECT @Count AS ViolationCount;
END
GO

/* ---------- 2) Duplicate / overlapping leave ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Integrity_CheckDuplicateLeaveRequests
    @RunId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.IntegrityViolationLog
        (RunId, CheckCode, Severity, EntityName, EntityId, EmployeeId, ViolationDetail)
    SELECT
        @RunId,
        N'DUPLICATE_OVERLAP',
        N'Critical',
        N'LeaveRequests',
        a.LeaveRequestId,
        a.EmployeeId,
        CONCAT(N'Overlapping leave: Request ', a.LeaveRequestId, N' (', a.StartDate, N'–', a.EndDate,
               N') overlaps Request ', b.LeaveRequestId, N' (', b.StartDate, N'–', b.EndDate,
               N') Status=', a.Status, N'/', b.Status)
    FROM dbo.LeaveRequests a
    INNER JOIN dbo.LeaveRequests b
        ON a.EmployeeId = b.EmployeeId
       AND a.LeaveRequestId < b.LeaveRequestId
       AND a.IsCancelled = 0 AND b.IsCancelled = 0
       AND a.Status IN (N'Pending', N'Approved')
       AND b.Status IN (N'Pending', N'Approved')
       AND a.StartDate <= b.EndDate
       AND b.StartDate <= a.EndDate;

    SELECT @@ROWCOUNT AS ViolationCount;
END
GO

/* ---------- 3) Invalid / orphan foreign key references ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Integrity_CheckInvalidForeignKeys
    @RunId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Count INT = 0;

    /* LeaveRequests → Employees (defensive; FK should prevent this) */
    INSERT INTO dbo.IntegrityViolationLog (RunId, CheckCode, Severity, EntityName, EntityId, EmployeeId, ViolationDetail)
    SELECT @RunId, N'ORPHAN_FK', N'Critical', N'LeaveRequests', lr.LeaveRequestId, lr.EmployeeId,
           CONCAT(N'LeaveRequests.EmployeeId=', lr.EmployeeId, N' has no matching Employees row')
    FROM dbo.LeaveRequests lr
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Employees e WHERE e.EmployeeId = lr.EmployeeId);
    SET @Count += @@ROWCOUNT;

    INSERT INTO dbo.IntegrityViolationLog (RunId, CheckCode, Severity, EntityName, EntityId, EmployeeId, ViolationDetail)
    SELECT @RunId, N'ORPHAN_FK', N'Critical', N'LeaveRequests', lr.LeaveRequestId, lr.EmployeeId,
           CONCAT(N'LeaveRequests.LeaveTypeId=', lr.LeaveTypeId, N' has no matching LeaveTypes row')
    FROM dbo.LeaveRequests lr
    WHERE NOT EXISTS (SELECT 1 FROM dbo.LeaveTypes lt WHERE lt.LeaveTypeId = lr.LeaveTypeId);
    SET @Count += @@ROWCOUNT;

    INSERT INTO dbo.IntegrityViolationLog (RunId, CheckCode, Severity, EntityName, EntityId, EmployeeId, ViolationDetail)
    SELECT @RunId, N'ORPHAN_FK', N'High', N'LeaveRequests', lr.LeaveRequestId, lr.EmployeeId,
           CONCAT(N'LeaveRequests.ApprovedBy=', lr.ApprovedBy, N' has no matching Employees row')
    FROM dbo.LeaveRequests lr
    WHERE lr.ApprovedBy IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.Employees e WHERE e.EmployeeId = lr.ApprovedBy);
    SET @Count += @@ROWCOUNT;

    INSERT INTO dbo.IntegrityViolationLog (RunId, CheckCode, Severity, EntityName, EntityId, EmployeeId, ViolationDetail)
    SELECT @RunId, N'ORPHAN_FK', N'Critical', N'Users', u.UserId, u.EmployeeId,
           CONCAT(N'Users.RoleId=', u.RoleId, N' has no matching Roles row')
    FROM dbo.Users u
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Roles r WHERE r.RoleId = u.RoleId);
    SET @Count += @@ROWCOUNT;

    INSERT INTO dbo.IntegrityViolationLog (RunId, CheckCode, Severity, EntityName, EntityId, EmployeeId, ViolationDetail)
    SELECT @RunId, N'ORPHAN_FK', N'High', N'Employees', e.EmployeeId, e.EmployeeId,
           CONCAT(N'Employees.DepartmentId=', e.DepartmentId, N' has no matching Departments row')
    FROM dbo.Employees e
    WHERE e.DepartmentId IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.Departments d WHERE d.DepartmentId = e.DepartmentId);
    SET @Count += @@ROWCOUNT;

    INSERT INTO dbo.IntegrityViolationLog (RunId, CheckCode, Severity, EntityName, EntityId, EmployeeId, ViolationDetail)
    SELECT @RunId, N'ORPHAN_FK', N'Medium', N'Employees', e.EmployeeId, e.EmployeeId,
           CONCAT(N'Employees.ManagerId=', e.ManagerId, N' has no matching Employees row')
    FROM dbo.Employees e
    WHERE e.ManagerId IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.Employees m WHERE m.EmployeeId = e.ManagerId);
    SET @Count += @@ROWCOUNT;

    IF OBJECT_ID(N'dbo.LeaveBalances', N'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.IntegrityViolationLog (RunId, CheckCode, Severity, EntityName, EntityId, EmployeeId, ViolationDetail)
        SELECT @RunId, N'ORPHAN_FK', N'High', N'LeaveBalances', lb.LeaveBalanceId, lb.EmployeeId,
               CONCAT(N'LeaveBalances references missing EmployeeId=', lb.EmployeeId)
        FROM dbo.LeaveBalances lb
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Employees e WHERE e.EmployeeId = lb.EmployeeId);
        SET @Count += @@ROWCOUNT;
    END

    SELECT @Count AS ViolationCount;
END
GO

/* ---------- 4) Holiday mapping ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Integrity_CheckHolidayMapping
    @RunId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    /*
      Flag approved/pending leave that includes an active non-optional holiday
      when the applicable policy has ExcludeHolidays = 1.
    */
    ;WITH ApplicablePolicy AS (
        SELECT
            lr.LeaveRequestId,
            lr.EmployeeId,
            lr.StartDate,
            lr.EndDate,
            COALESCE(tp.ExcludeHolidays, gp.ExcludeHolidays, CAST(1 AS BIT)) AS ExcludeHolidays
        FROM dbo.LeaveRequests lr
        OUTER APPLY (
            SELECT TOP 1 p.ExcludeHolidays
            FROM dbo.LeavePolicies p
            WHERE p.IsActive = 1
              AND p.LeaveTypeId = lr.LeaveTypeId
              AND p.EffectiveFrom <= lr.StartDate
              AND (p.EffectiveTo IS NULL OR p.EffectiveTo >= lr.StartDate)
            ORDER BY p.PolicyId
        ) tp
        OUTER APPLY (
            SELECT TOP 1 p.ExcludeHolidays
            FROM dbo.LeavePolicies p
            WHERE p.IsActive = 1
              AND p.LeaveTypeId IS NULL
              AND p.EffectiveFrom <= lr.StartDate
              AND (p.EffectiveTo IS NULL OR p.EffectiveTo >= lr.StartDate)
            ORDER BY p.PolicyId
        ) gp
        WHERE lr.IsCancelled = 0
          AND lr.Status IN (N'Pending', N'Approved')
    )
    INSERT INTO dbo.IntegrityViolationLog
        (RunId, CheckCode, Severity, EntityName, EntityId, EmployeeId, ViolationDetail)
    SELECT DISTINCT
        @RunId,
        N'HOLIDAY_MAPPING',
        N'Medium',
        N'LeaveRequests',
        ap.LeaveRequestId,
        ap.EmployeeId,
        CONCAT(N'Leave ', ap.LeaveRequestId, N' includes holiday ', h.HolidayName,
               N' on ', CONVERT(NVARCHAR(10), h.HolidayDate, 23),
               N' but policy ExcludeHolidays=1 (TotalDays may be overstated)')
    FROM ApplicablePolicy ap
    INNER JOIN dbo.Holidays h
        ON h.IsActive = 1
       AND h.IsOptional = 0
       AND h.HolidayDate BETWEEN ap.StartDate AND ap.EndDate
    WHERE ap.ExcludeHolidays = 1;

    SELECT @@ROWCOUNT AS ViolationCount;
END
GO

/* ---------- 5) Policy violations ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Integrity_CheckPolicyViolations
    @RunId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Count INT = 0;

    ;WITH ReqPolicy AS (
        SELECT
            lr.LeaveRequestId,
            lr.EmployeeId,
            lr.LeaveTypeId,
            lr.StartDate,
            lr.EndDate,
            lr.TotalDays,
            lr.CreatedDate,
            lr.Status,
            COALESCE(tp.MaxConsecutiveDays, gp.MaxConsecutiveDays) AS MaxConsecutiveDays,
            COALESCE(tp.MinNoticeDays, gp.MinNoticeDays) AS MinNoticeDays,
            COALESCE(tp.MaxRequestsPerYear, gp.MaxRequestsPerYear) AS MaxRequestsPerYear,
            COALESCE(tp.PolicyCode, gp.PolicyCode) AS PolicyCode
        FROM dbo.LeaveRequests lr
        OUTER APPLY (
            SELECT TOP 1 p.*
            FROM dbo.LeavePolicies p
            WHERE p.IsActive = 1 AND p.LeaveTypeId = lr.LeaveTypeId
              AND p.EffectiveFrom <= lr.StartDate
              AND (p.EffectiveTo IS NULL OR p.EffectiveTo >= lr.StartDate)
            ORDER BY p.PolicyId
        ) tp
        OUTER APPLY (
            SELECT TOP 1 p.*
            FROM dbo.LeavePolicies p
            WHERE p.IsActive = 1 AND p.LeaveTypeId IS NULL
              AND p.EffectiveFrom <= lr.StartDate
              AND (p.EffectiveTo IS NULL OR p.EffectiveTo >= lr.StartDate)
            ORDER BY p.PolicyId
        ) gp
        WHERE lr.IsCancelled = 0
          AND lr.Status IN (N'Pending', N'Approved')
    )
    INSERT INTO dbo.IntegrityViolationLog
        (RunId, CheckCode, Severity, EntityName, EntityId, EmployeeId, ViolationDetail)
    SELECT
        @RunId,
        N'POLICY_MAX_DAYS',
        N'High',
        N'LeaveRequests',
        rp.LeaveRequestId,
        rp.EmployeeId,
        CONCAT(N'TotalDays=', rp.TotalDays, N' exceeds MaxConsecutiveDays=', rp.MaxConsecutiveDays,
               N' (policy ', ISNULL(rp.PolicyCode, N'N/A'), N')')
    FROM ReqPolicy rp
    WHERE rp.MaxConsecutiveDays IS NOT NULL
      AND rp.TotalDays > rp.MaxConsecutiveDays;

    SET @Count += @@ROWCOUNT;

    ;WITH ReqPolicy2 AS (
        SELECT
            lr.LeaveRequestId,
            lr.EmployeeId,
            lr.StartDate,
            lr.CreatedDate,
            COALESCE(tp.MinNoticeDays, gp.MinNoticeDays) AS MinNoticeDays,
            COALESCE(tp.PolicyCode, gp.PolicyCode) AS PolicyCode
        FROM dbo.LeaveRequests lr
        OUTER APPLY (
            SELECT TOP 1 p.MinNoticeDays, p.PolicyCode
            FROM dbo.LeavePolicies p
            WHERE p.IsActive = 1 AND p.LeaveTypeId = lr.LeaveTypeId
              AND p.EffectiveFrom <= lr.StartDate
              AND (p.EffectiveTo IS NULL OR p.EffectiveTo >= lr.StartDate)
            ORDER BY p.PolicyId
        ) tp
        OUTER APPLY (
            SELECT TOP 1 p.MinNoticeDays, p.PolicyCode
            FROM dbo.LeavePolicies p
            WHERE p.IsActive = 1 AND p.LeaveTypeId IS NULL
              AND p.EffectiveFrom <= lr.StartDate
              AND (p.EffectiveTo IS NULL OR p.EffectiveTo >= lr.StartDate)
            ORDER BY p.PolicyId
        ) gp
        WHERE lr.IsCancelled = 0 AND lr.Status IN (N'Pending', N'Approved')
    )
    INSERT INTO dbo.IntegrityViolationLog
        (RunId, CheckCode, Severity, EntityName, EntityId, EmployeeId, ViolationDetail)
    SELECT
        @RunId,
        N'POLICY_NOTICE',
        N'Medium',
        N'LeaveRequests',
        rp.LeaveRequestId,
        rp.EmployeeId,
        CONCAT(N'Insufficient notice: StartDate=', CONVERT(NVARCHAR(10), rp.StartDate, 23),
               N' CreatedDate=', CONVERT(NVARCHAR(10), rp.CreatedDate, 23),
               N' required MinNoticeDays=', rp.MinNoticeDays,
               N' (policy ', ISNULL(rp.PolicyCode, N'N/A'), N')')
    FROM ReqPolicy2 rp
    WHERE rp.MinNoticeDays IS NOT NULL
      AND DATEDIFF(DAY, CAST(rp.CreatedDate AS DATE), rp.StartDate) < rp.MinNoticeDays;

    SET @Count += @@ROWCOUNT;

    /* Yearly request cap */
    ;WITH YearlyCounts AS (
        SELECT
            lr.EmployeeId,
            lr.LeaveTypeId,
            YEAR(lr.StartDate) AS LeaveYear,
            COUNT(*) AS RequestCount,
            COALESCE(tp.MaxRequestsPerYear, gp.MaxRequestsPerYear) AS MaxRequestsPerYear,
            COALESCE(tp.PolicyCode, gp.PolicyCode) AS PolicyCode,
            MAX(lr.LeaveRequestId) AS SampleLeaveRequestId
        FROM dbo.LeaveRequests lr
        OUTER APPLY (
            SELECT TOP 1 p.MaxRequestsPerYear, p.PolicyCode
            FROM dbo.LeavePolicies p
            WHERE p.IsActive = 1 AND p.LeaveTypeId = lr.LeaveTypeId
            ORDER BY p.PolicyId
        ) tp
        OUTER APPLY (
            SELECT TOP 1 p.MaxRequestsPerYear, p.PolicyCode
            FROM dbo.LeavePolicies p
            WHERE p.IsActive = 1 AND p.LeaveTypeId IS NULL
            ORDER BY p.PolicyId
        ) gp
        WHERE lr.IsCancelled = 0 AND lr.Status IN (N'Pending', N'Approved')
        GROUP BY lr.EmployeeId, lr.LeaveTypeId, YEAR(lr.StartDate),
                 tp.MaxRequestsPerYear, gp.MaxRequestsPerYear, tp.PolicyCode, gp.PolicyCode
    )
    INSERT INTO dbo.IntegrityViolationLog
        (RunId, CheckCode, Severity, EntityName, EntityId, EmployeeId, ViolationDetail)
    SELECT
        @RunId,
        N'POLICY_MAX_REQUESTS',
        N'High',
        N'LeaveRequests',
        yc.SampleLeaveRequestId,
        yc.EmployeeId,
        CONCAT(N'RequestCount=', yc.RequestCount, N' exceeds MaxRequestsPerYear=', yc.MaxRequestsPerYear,
               N' for LeaveTypeId=', yc.LeaveTypeId, N' Year=', yc.LeaveYear,
               N' (policy ', ISNULL(yc.PolicyCode, N'N/A'), N')')
    FROM YearlyCounts yc
    WHERE yc.MaxRequestsPerYear IS NOT NULL
      AND yc.RequestCount > yc.MaxRequestsPerYear;

    SET @Count += @@ROWCOUNT;
    SELECT @Count AS ViolationCount;
END
GO

/* ---------- Orchestrator: run all integrity checks ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Integrity_RunAllChecks
    @BalanceYear INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunId INT;
    DECLARE @Total INT = 0;
    DECLARE @Checks INT = 5;
    DECLARE @RunStatus NVARCHAR(20);
    DECLARE @Details NVARCHAR(MAX);
    DECLARE @ErrMsg NVARCHAR(4000);
    DECLARE @ErrNum INT;
    DECLARE @ErrSev INT;
    DECLARE @ErrState INT;

    EXEC dbo.sp_Compliance_LogStart N'ELM_Compliance_Integrity', N'RunAllChecks', @RunId OUTPUT;

    BEGIN TRY
        EXEC dbo.sp_Integrity_CheckLeaveBalanceConsistency @RunId = @RunId, @BalanceYear = @BalanceYear;
        EXEC dbo.sp_Integrity_CheckDuplicateLeaveRequests @RunId = @RunId;
        EXEC dbo.sp_Integrity_CheckInvalidForeignKeys @RunId = @RunId;
        EXEC dbo.sp_Integrity_CheckHolidayMapping @RunId = @RunId;
        EXEC dbo.sp_Integrity_CheckPolicyViolations @RunId = @RunId;

        SELECT @Total = COUNT(*)
        FROM dbo.IntegrityViolationLog
        WHERE RunId = @RunId;

        SET @RunStatus = CASE WHEN @Total = 0 THEN N'Success' ELSE N'Warning' END;
        SET @Details = CONCAT(N'Integrity checks completed. Violations=', @Total);

        EXEC dbo.sp_Compliance_LogEnd
            @RunId = @RunId,
            @Status = @RunStatus,
            @ChecksRun = @Checks,
            @ViolationsFound = @Total,
            @Details = @Details;

        SELECT
            @RunId AS RunId,
            @Checks AS ChecksRun,
            @Total AS ViolationsFound,
            @RunStatus AS Status;
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @ErrNum = ERROR_NUMBER();
        SET @ErrSev = ERROR_SEVERITY();
        SET @ErrState = ERROR_STATE();

        EXEC dbo.sp_Audit_LogException
            @SourceProc = N'sp_Integrity_RunAllChecks',
            @ErrorNumber = @ErrNum,
            @ErrorSeverity = @ErrSev,
            @ErrorState = @ErrState,
            @ErrorMessage = @ErrMsg;

        EXEC dbo.sp_Compliance_LogEnd
            @RunId = @RunId,
            @Status = N'Failed',
            @ErrorMessage = @ErrMsg;

        THROW;
    END CATCH
END
GO

PRINT '03_Integrity_Validation_Procedures completed.';
GO
