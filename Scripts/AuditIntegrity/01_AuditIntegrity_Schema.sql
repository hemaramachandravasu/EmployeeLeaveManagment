/*
================================================================================
  Audit Integrity & Compliance — Schema
  Database: EmployeeLeaveDb

  Tables:
    Holidays, LeavePolicies, UserActivityLog,
    IntegrityViolationLog, ComplianceRunLog, DatabaseExceptionLog
================================================================================
*/
USE EmployeeLeaveDb;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------- Holidays (company calendar) ---------- */
IF OBJECT_ID(N'dbo.Holidays', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Holidays
    (
        HolidayId     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        HolidayDate   DATE NOT NULL,
        HolidayName   NVARCHAR(200) NOT NULL,
        IsOptional    BIT NOT NULL CONSTRAINT DF_Holidays_Optional DEFAULT (0),
        RegionCode    NVARCHAR(20) NULL,
        IsActive      BIT NOT NULL CONSTRAINT DF_Holidays_Active DEFAULT (1),
        CreatedAt     DATETIME2 NOT NULL CONSTRAINT DF_Holidays_Created DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_Holidays_Date_Region UNIQUE (HolidayDate, RegionCode)
    );
END
GO

SET QUOTED_IDENTIFIER ON;
IF OBJECT_ID(N'dbo.Holidays', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Holidays') AND name = N'IX_Holidays_Date_Active')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Holidays_Date_Active
        ON dbo.Holidays (HolidayDate) INCLUDE (HolidayName, IsOptional)
        WHERE IsActive = 1;
END
GO

/* ---------- Leave policies (business rules) ---------- */
IF OBJECT_ID(N'dbo.LeavePolicies', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LeavePolicies
    (
        PolicyId           INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        PolicyCode         NVARCHAR(50) NOT NULL,
        PolicyName         NVARCHAR(200) NOT NULL,
        LeaveTypeId        INT NULL,  -- NULL = applies to all leave types
        MaxConsecutiveDays INT NULL,
        MinNoticeDays      INT NULL,
        MaxRequestsPerYear INT NULL,
        RequireApproval    BIT NOT NULL CONSTRAINT DF_LeavePolicies_RequireApproval DEFAULT (1),
        AllowWeekendSpan   BIT NOT NULL CONSTRAINT DF_LeavePolicies_AllowWeekend DEFAULT (1),
        ExcludeHolidays    BIT NOT NULL CONSTRAINT DF_LeavePolicies_ExcludeHolidays DEFAULT (1),
        IsActive           BIT NOT NULL CONSTRAINT DF_LeavePolicies_Active DEFAULT (1),
        EffectiveFrom      DATE NOT NULL CONSTRAINT DF_LeavePolicies_From DEFAULT (CAST(SYSUTCDATETIME() AS DATE)),
        EffectiveTo        DATE NULL,
        Notes              NVARCHAR(500) NULL,
        CONSTRAINT UQ_LeavePolicies_Code UNIQUE (PolicyCode),
        CONSTRAINT FK_LeavePolicies_LeaveType FOREIGN KEY (LeaveTypeId) REFERENCES dbo.LeaveTypes (LeaveTypeId)
    );
END
GO

/* ---------- Application user activity (login / API actions) ---------- */
IF OBJECT_ID(N'dbo.UserActivityLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.UserActivityLog
    (
        ActivityId     BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        UserId         INT NULL,
        UserName       NVARCHAR(100) NULL,
        ActivityType   NVARCHAR(50) NOT NULL,  -- Login, Logout, View, Export, Approve, Reject, Apply, Config
        EntityName     NVARCHAR(128) NULL,
        EntityId       INT NULL,
        ActivityDetail NVARCHAR(1000) NULL,
        IpAddress      NVARCHAR(64) NULL,
        Success        BIT NOT NULL CONSTRAINT DF_UserActivity_Success DEFAULT (1),
        ActivityAt     DATETIME2 NOT NULL CONSTRAINT DF_UserActivity_At DEFAULT (SYSUTCDATETIME())
    );

    CREATE NONCLUSTERED INDEX IX_UserActivity_At
        ON dbo.UserActivityLog (ActivityAt DESC) INCLUDE (UserName, ActivityType, Success);
    CREATE NONCLUSTERED INDEX IX_UserActivity_User
        ON dbo.UserActivityLog (UserName, ActivityAt DESC);
END
GO

/* ---------- Integrity violation findings ---------- */
IF OBJECT_ID(N'dbo.IntegrityViolationLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.IntegrityViolationLog
    (
        ViolationId     BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RunId           INT NULL,
        CheckCode       NVARCHAR(50) NOT NULL,
        Severity        NVARCHAR(20) NOT NULL,  -- Critical / High / Medium / Low
        EntityName      NVARCHAR(128) NOT NULL,
        EntityId        INT NULL,
        EmployeeId      INT NULL,
        ViolationDetail NVARCHAR(MAX) NOT NULL,
        DetectedAt      DATETIME2 NOT NULL CONSTRAINT DF_IntegrityViolation_At DEFAULT (SYSUTCDATETIME()),
        IsResolved      BIT NOT NULL CONSTRAINT DF_IntegrityViolation_Resolved DEFAULT (0),
        ResolvedAt      DATETIME2 NULL,
        ResolvedBy      NVARCHAR(100) NULL,
        ResolutionNotes NVARCHAR(500) NULL
    );

    CREATE NONCLUSTERED INDEX IX_IntegrityViolation_Detected
        ON dbo.IntegrityViolationLog (DetectedAt DESC) INCLUDE (CheckCode, Severity, IsResolved);
    CREATE NONCLUSTERED INDEX IX_IntegrityViolation_Open
        ON dbo.IntegrityViolationLog (IsResolved, Severity) INCLUDE (CheckCode, EntityName);
END
GO

/* ---------- Compliance / validation run log ---------- */
IF OBJECT_ID(N'dbo.ComplianceRunLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ComplianceRunLog
    (
        RunId          INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        JobName        NVARCHAR(128) NOT NULL,
        StepName       NVARCHAR(128) NOT NULL,
        StartTime      DATETIME2 NOT NULL CONSTRAINT DF_ComplianceRun_Start DEFAULT (SYSUTCDATETIME()),
        EndTime        DATETIME2 NULL,
        Status         NVARCHAR(20) NOT NULL,  -- Running / Success / Failed / Warning
        ChecksRun      INT NULL,
        ViolationsFound INT NULL,
        Details        NVARCHAR(MAX) NULL,
        ErrorMessage   NVARCHAR(4000) NULL
    );
END
GO

/* ---------- Database / validation exception log ---------- */
IF OBJECT_ID(N'dbo.DatabaseExceptionLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DatabaseExceptionLog
    (
        ExceptionId    BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        SourceProc     NVARCHAR(256) NULL,
        ErrorNumber    INT NULL,
        ErrorSeverity  INT NULL,
        ErrorState     INT NULL,
        ErrorMessage   NVARCHAR(4000) NOT NULL,
        CapturedAt     DATETIME2 NOT NULL CONSTRAINT DF_DbException_At DEFAULT (SYSUTCDATETIME()),
        ContextInfo    NVARCHAR(1000) NULL
    );

    CREATE NONCLUSTERED INDEX IX_DatabaseException_At
        ON dbo.DatabaseExceptionLog (CapturedAt DESC);
END
GO

/* ---------- Seed holidays (sample India-style public holidays for current/next year) ---------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Holidays)
BEGIN
    DECLARE @Y INT = YEAR(SYSUTCDATETIME());
    INSERT INTO dbo.Holidays (HolidayDate, HolidayName, IsOptional, RegionCode) VALUES
        (DATEFROMPARTS(@Y, 1, 26), N'Republic Day', 0, N'IN'),
        (DATEFROMPARTS(@Y, 8, 15), N'Independence Day', 0, N'IN'),
        (DATEFROMPARTS(@Y, 10, 2), N'Gandhi Jayanti', 0, N'IN'),
        (DATEFROMPARTS(@Y, 12, 25), N'Christmas', 0, N'IN'),
        (DATEFROMPARTS(@Y + 1, 1, 26), N'Republic Day', 0, N'IN'),
        (DATEFROMPARTS(@Y + 1, 8, 15), N'Independence Day', 0, N'IN'),
        (DATEFROMPARTS(@Y + 1, 10, 2), N'Gandhi Jayanti', 0, N'IN'),
        (DATEFROMPARTS(@Y + 1, 12, 25), N'Christmas', 0, N'IN');
END
GO

/* ---------- Seed leave policies ---------- */
IF NOT EXISTS (SELECT 1 FROM dbo.LeavePolicies)
BEGIN
    DECLARE @CasualId INT = (SELECT TOP 1 LeaveTypeId FROM dbo.LeaveTypes WHERE LeaveTypeName LIKE N'%Casual%' OR LeaveTypeName LIKE N'%Annual%' OR LeaveTypeName LIKE N'%Paid%');
    DECLARE @SickId INT = (SELECT TOP 1 LeaveTypeId FROM dbo.LeaveTypes WHERE LeaveTypeName LIKE N'%Sick%');

    INSERT INTO dbo.LeavePolicies
        (PolicyCode, PolicyName, LeaveTypeId, MaxConsecutiveDays, MinNoticeDays, MaxRequestsPerYear,
         RequireApproval, AllowWeekendSpan, ExcludeHolidays, Notes)
    VALUES
        (N'POL_GENERAL', N'General leave policy', NULL, 15, 1, 24, 1, 1, 1,
         N'Default rules for all leave types when no type-specific policy exists'),
        (N'POL_CASUAL', N'Casual / annual leave policy', @CasualId, 10, 2, 12, 1, 1, 1,
         N'Max 10 consecutive days; 2 days notice'),
        (N'POL_SICK', N'Sick leave policy', @SickId, 7, 0, 18, 1, 1, 0,
         N'Sick leave may start same day; holidays may count');
END
GO

/* Ensure LeaveBalances exists even if Maintenance module not deployed */
IF OBJECT_ID(N'dbo.LeaveBalances', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LeaveBalances (
        LeaveBalanceId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        EmployeeId     INT NOT NULL,
        LeaveTypeId    INT NOT NULL,
        BalanceYear    INT NOT NULL,
        EntitledDays   DECIMAL(9,2) NOT NULL CONSTRAINT DF_AI_LeaveBalances_Entitled DEFAULT (0),
        UsedDays       DECIMAL(9,2) NOT NULL CONSTRAINT DF_AI_LeaveBalances_Used DEFAULT (0),
        RemainingDays  AS (EntitledDays - UsedDays) PERSISTED,
        IsHistorical   BIT NOT NULL CONSTRAINT DF_AI_LeaveBalances_IsHistorical DEFAULT (0),
        CreatedAt      DATETIME2 NOT NULL CONSTRAINT DF_AI_LeaveBalances_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ClosedAt       DATETIME2 NULL,
        CONSTRAINT FK_AI_LeaveBalances_Employee FOREIGN KEY (EmployeeId) REFERENCES dbo.Employees(EmployeeId),
        CONSTRAINT FK_AI_LeaveBalances_LeaveType FOREIGN KEY (LeaveTypeId) REFERENCES dbo.LeaveTypes(LeaveTypeId),
        CONSTRAINT UQ_AI_LeaveBalances_EmpTypeYear UNIQUE (EmployeeId, LeaveTypeId, BalanceYear)
    );
END
GO

PRINT '01_AuditIntegrity_Schema completed.';
GO
