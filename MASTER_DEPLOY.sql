/*
  MASTER_DEPLOY.sql
  -----------------
  Single deployment script for Employee Leave Management API.
  Run on any SQL Server instance (SSMS, Azure Data Studio, or sqlcmd).

  Example:
    sqlcmd -S localhost -E -C -i MASTER_DEPLOY.sql

  Notes:
  - Creates database EmployeeLeaveDb if missing.
  - Drops and recreates application tables (destructive for app data).
  - Creates all stored procedures, audit objects, and optional seed data.
  - Schema matches the .NET repositories in EmployeeLeaveManagment/Data.
*/

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF DB_ID(N'EmployeeLeaveDb') IS NULL
BEGIN
    CREATE DATABASE EmployeeLeaveDb;
END
GO

USE EmployeeLeaveDb;
GO

/* ===========================
   1) DROP OBJECTS (dependency order)
   =========================== */
IF OBJECT_ID(N'dbo.trg_Employees_Audit', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_Employees_Audit;
IF OBJECT_ID(N'dbo.trg_Leaves_Audit', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_Leaves_Audit;
IF OBJECT_ID(N'dbo.trg_LeaveRequests_Audit', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_LeaveRequests_Audit;
GO

IF OBJECT_ID(N'dbo.LeaveRequestsArchive', N'U') IS NOT NULL DROP TABLE dbo.LeaveRequestsArchive;
IF OBJECT_ID(N'dbo.LeavesArchive', N'U') IS NOT NULL DROP TABLE dbo.LeavesArchive;
IF OBJECT_ID(N'dbo.AuditLogs', N'U') IS NOT NULL DROP TABLE dbo.AuditLogs;
IF OBJECT_ID(N'dbo.LeaveRequests', N'U') IS NOT NULL DROP TABLE dbo.LeaveRequests;
IF OBJECT_ID(N'dbo.Leaves', N'U') IS NOT NULL DROP TABLE dbo.Leaves;
IF OBJECT_ID(N'dbo.Users', N'U') IS NOT NULL DROP TABLE dbo.Users;
IF OBJECT_ID(N'dbo.LeaveTypes', N'U') IS NOT NULL DROP TABLE dbo.LeaveTypes;
IF OBJECT_ID(N'dbo.Employees', N'U') IS NOT NULL DROP TABLE dbo.Employees;
IF OBJECT_ID(N'dbo.Roles', N'U') IS NOT NULL DROP TABLE dbo.Roles;
IF OBJECT_ID(N'dbo.Departments', N'U') IS NOT NULL DROP TABLE dbo.Departments;
GO

/* ===========================
   2) TABLES
   =========================== */
CREATE TABLE dbo.Departments (
    DepartmentId   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    DepartmentName NVARCHAR(200) NOT NULL,
    DepartmentCode NVARCHAR(50)  NOT NULL,
    Description    NVARCHAR(500) NULL,
    IsActive       BIT NOT NULL CONSTRAINT DF_Departments_IsActive DEFAULT (1),
    CreatedAt      DATETIME2 NOT NULL CONSTRAINT DF_Departments_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT UQ_Departments_DepartmentCode UNIQUE (DepartmentCode)
);
GO

CREATE TABLE dbo.Roles (
    RoleId      INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RoleName    NVARCHAR(50) NOT NULL,
    Description NVARCHAR(200) NULL,
    IsActive    BIT NOT NULL CONSTRAINT DF_Roles_IsActive DEFAULT (1),
    CreatedDate DATETIME2 NOT NULL CONSTRAINT DF_Roles_CreatedDate DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT UQ_Roles_RoleName UNIQUE (RoleName)
);
GO

CREATE TABLE dbo.LeaveTypes (
    LeaveTypeId   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    LeaveTypeName NVARCHAR(100) NOT NULL,
    TotalDays     INT NOT NULL CONSTRAINT DF_LeaveTypes_TotalDays DEFAULT (0),
    Description   NVARCHAR(500) NULL,
    IsActive      BIT NOT NULL CONSTRAINT DF_LeaveTypes_IsActive DEFAULT (1),
    CreatedDate   DATETIME2 NOT NULL CONSTRAINT DF_LeaveTypes_CreatedDate DEFAULT (SYSUTCDATETIME()),
    ModifiedDate  DATETIME2 NULL,
    CONSTRAINT UQ_LeaveTypes_Name UNIQUE (LeaveTypeName)
);
GO

CREATE TABLE dbo.Employees (
    EmployeeId     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    EmployeeCode   NVARCHAR(50)  NOT NULL,
    FirstName      NVARCHAR(100) NOT NULL,
    LastName       NVARCHAR(100) NULL,
    Gender         NVARCHAR(20)  NOT NULL,
    DateOfBirth    DATE NOT NULL,
    MobileNumber   NVARCHAR(20)  NOT NULL,
    Email          NVARCHAR(320) NOT NULL,
    DepartmentId   INT NOT NULL,
    ManagerId      INT NULL,
    JoinDate       DATE NOT NULL,
    Salary         DECIMAL(18,2) NOT NULL,
    Address        NVARCHAR(500) NULL,
    IsActive       BIT NOT NULL CONSTRAINT DF_Employees_IsActive DEFAULT (1),
    CreatedAt      DATETIME2 NOT NULL CONSTRAINT DF_Employees_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT UQ_Employees_EmployeeCode UNIQUE (EmployeeCode),
    CONSTRAINT FK_Employees_Department FOREIGN KEY (DepartmentId) REFERENCES dbo.Departments(DepartmentId),
    CONSTRAINT FK_Employees_Manager FOREIGN KEY (ManagerId) REFERENCES dbo.Employees(EmployeeId)
);
GO

CREATE TABLE dbo.Users (
    UserId       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    UserName     NVARCHAR(100) NOT NULL,
    PasswordHash NVARCHAR(500) NOT NULL,
    Email        NVARCHAR(320) NOT NULL,
    RoleId       INT NOT NULL,
    IsActive     BIT NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT (1),
    CreatedDate  DATETIME2 NOT NULL CONSTRAINT DF_Users_CreatedDate DEFAULT (SYSUTCDATETIME()),
    ModifiedDate DATETIME2 NULL,
    CONSTRAINT UQ_Users_UserName UNIQUE (UserName),
    CONSTRAINT FK_Users_Role FOREIGN KEY (RoleId) REFERENCES dbo.Roles(RoleId)
);
GO

CREATE TABLE dbo.LeaveRequests (
    LeaveRequestId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    EmployeeId     INT NOT NULL,
    LeaveTypeId    INT NOT NULL,
    StartDate      DATE NOT NULL,
    EndDate        DATE NOT NULL,
    TotalDays      AS (DATEDIFF(DAY, StartDate, EndDate) + 1) PERSISTED,
    Reason         NVARCHAR(500) NOT NULL,
    Status         NVARCHAR(50) NOT NULL CONSTRAINT DF_LeaveRequests_Status DEFAULT (N'Pending'),
    ApprovedBy     INT NULL,
    ApprovedDate   DATETIME2 NULL,
    Remarks        NVARCHAR(500) NULL,
    IsCancelled    BIT NOT NULL CONSTRAINT DF_LeaveRequests_IsCancelled DEFAULT (0),
    CreatedDate    DATETIME2 NOT NULL CONSTRAINT DF_LeaveRequests_CreatedDate DEFAULT (SYSUTCDATETIME()),
    ModifiedDate   DATETIME2 NULL,
    CONSTRAINT FK_LeaveRequests_Employee FOREIGN KEY (EmployeeId) REFERENCES dbo.Employees(EmployeeId),
    CONSTRAINT FK_LeaveRequests_LeaveType FOREIGN KEY (LeaveTypeId) REFERENCES dbo.LeaveTypes(LeaveTypeId),
    CONSTRAINT FK_LeaveRequests_ApprovedBy FOREIGN KEY (ApprovedBy) REFERENCES dbo.Employees(EmployeeId)
);
GO

CREATE TABLE dbo.AuditLogs (
    AuditId    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    TableName  NVARCHAR(128) NOT NULL,
    RecordId   INT NOT NULL,
    ActionType NVARCHAR(20) NOT NULL,
    OldValue   NVARCHAR(MAX) NULL,
    NewValue   NVARCHAR(MAX) NULL,
    ChangedBy  NVARCHAR(200) NULL,
    ChangedOn  DATETIME2 NOT NULL CONSTRAINT DF_AuditLogs_ChangedOn DEFAULT (SYSUTCDATETIME())
);
GO

CREATE TABLE dbo.LeaveRequestsArchive (
    LeaveRequestId INT NOT NULL,
    EmployeeId     INT NOT NULL,
    LeaveTypeId    INT NOT NULL,
    StartDate      DATE NOT NULL,
    EndDate        DATE NOT NULL,
    TotalDays      INT NOT NULL,
    Reason         NVARCHAR(500) NOT NULL,
    Status         NVARCHAR(50) NOT NULL,
    ApprovedBy     INT NULL,
    ApprovedDate   DATETIME2 NULL,
    Remarks        NVARCHAR(500) NULL,
    IsCancelled    BIT NOT NULL,
    CreatedDate    DATETIME2 NOT NULL,
    ModifiedDate   DATETIME2 NULL,
    ArchivedAt     DATETIME2 NOT NULL CONSTRAINT DF_LeaveRequestsArchive_ArchivedAt DEFAULT (SYSUTCDATETIME())
);
GO

/* ===========================
   3) INDEXES
   =========================== */
CREATE NONCLUSTERED INDEX IX_Employees_DepartmentId ON dbo.Employees(DepartmentId) INCLUDE (FirstName, LastName, Email, IsActive);
CREATE NONCLUSTERED INDEX IX_Employees_FirstName ON dbo.Employees(FirstName) WHERE IsActive = 1;
CREATE NONCLUSTERED INDEX IX_LeaveRequests_Employee_StartDate ON dbo.LeaveRequests(EmployeeId, StartDate) INCLUDE (EndDate, Status, LeaveTypeId);
CREATE NONCLUSTERED INDEX IX_LeaveRequests_Status_StartDate ON dbo.LeaveRequests(Status, StartDate) INCLUDE (EndDate, EmployeeId, LeaveTypeId);
CREATE NONCLUSTERED INDEX IX_AuditLogs_Table_ChangedOn ON dbo.AuditLogs(TableName, ChangedOn);
CREATE NONCLUSTERED INDEX IX_AuditLogs_RecordId ON dbo.AuditLogs(RecordId);
GO

/* ===========================
   4) AUDIT TRIGGERS
   =========================== */
CREATE TRIGGER dbo.trg_Employees_Audit
ON dbo.Employees
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditLogs (TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy)
    SELECT
        N'Employees',
        COALESCE(i.EmployeeId, d.EmployeeId),
        CASE
            WHEN i.EmployeeId IS NOT NULL AND d.EmployeeId IS NULL THEN N'Insert'
            WHEN i.EmployeeId IS NOT NULL AND d.EmployeeId IS NOT NULL THEN N'Update'
            ELSE N'Delete'
        END,
        CASE WHEN d.EmployeeId IS NULL THEN NULL ELSE (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.EmployeeId IS NULL THEN NULL ELSE (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CONCAT(SUSER_SNAME(), N' | ', APP_NAME())
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.EmployeeId = d.EmployeeId;
END
GO

CREATE TRIGGER dbo.trg_LeaveRequests_Audit
ON dbo.LeaveRequests
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditLogs (TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy)
    SELECT
        N'LeaveRequests',
        COALESCE(i.LeaveRequestId, d.LeaveRequestId),
        CASE
            WHEN i.LeaveRequestId IS NOT NULL AND d.LeaveRequestId IS NULL THEN N'Insert'
            WHEN i.LeaveRequestId IS NOT NULL AND d.LeaveRequestId IS NOT NULL THEN N'Update'
            ELSE N'Delete'
        END,
        CASE WHEN d.LeaveRequestId IS NULL THEN NULL ELSE (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.LeaveRequestId IS NULL THEN NULL ELSE (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CONCAT(SUSER_SNAME(), N' | ', APP_NAME())
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.LeaveRequestId = d.LeaveRequestId;
END
GO

/* ===========================
   5) EMPLOYEE STORED PROCEDURES
   =========================== */
CREATE OR ALTER PROCEDURE dbo.sp_AddEmployee
    @EmployeeCode   NVARCHAR(50),
    @FirstName      NVARCHAR(100),
    @LastName       NVARCHAR(100) = NULL,
    @Gender         NVARCHAR(20),
    @DateOfBirth    DATE,
    @MobileNumber   NVARCHAR(20),
    @Email          NVARCHAR(320),
    @DepartmentId   INT,
    @ManagerId      INT = NULL,
    @JoinDate       DATE,
    @Salary         DECIMAL(18,2),
    @Address        NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.Employees (
        EmployeeCode, FirstName, LastName, Gender, DateOfBirth, MobileNumber, Email,
        DepartmentId, ManagerId, JoinDate, Salary, Address
    )
    VALUES (
        @EmployeeCode, @FirstName, @LastName, @Gender, @DateOfBirth, @MobileNumber, @Email,
        @DepartmentId, @ManagerId, @JoinDate, @Salary, @Address
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_UpdateEmployee
    @EmployeeId     INT,
    @EmployeeCode   NVARCHAR(50),
    @FirstName      NVARCHAR(100),
    @LastName       NVARCHAR(100) = NULL,
    @Gender         NVARCHAR(20),
    @DateOfBirth    DATE,
    @MobileNumber   NVARCHAR(20),
    @Email          NVARCHAR(320),
    @DepartmentId   INT,
    @ManagerId      INT = NULL,
    @JoinDate       DATE,
    @Salary         DECIMAL(18,2),
    @Address        NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Employees
    SET EmployeeCode = @EmployeeCode,
        FirstName = @FirstName,
        LastName = @LastName,
        Gender = @Gender,
        DateOfBirth = @DateOfBirth,
        MobileNumber = @MobileNumber,
        Email = @Email,
        DepartmentId = @DepartmentId,
        ManagerId = @ManagerId,
        JoinDate = @JoinDate,
        Salary = @Salary,
        Address = @Address
    WHERE EmployeeId = @EmployeeId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteEmployee
    @EmployeeId INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Employees SET IsActive = 0 WHERE EmployeeId = @EmployeeId;
END
GO

/* ===========================
   6) LEAVE STORED PROCEDURES
   =========================== */
CREATE OR ALTER PROCEDURE dbo.sp_GetAllLeaveRequests
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        lr.LeaveRequestId,
        lr.EmployeeId,
        lr.LeaveTypeId,
        lr.StartDate,
        lr.EndDate,
        lr.TotalDays,
        lr.Reason,
        lr.Status,
        lr.Remarks
    FROM dbo.LeaveRequests lr
    WHERE lr.IsCancelled = 0
    ORDER BY lr.CreatedDate DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetLeaveById
    @LeaveRequestId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        lr.LeaveRequestId,
        lr.EmployeeId,
        lr.LeaveTypeId,
        lr.StartDate,
        lr.EndDate,
        lr.TotalDays,
        lr.Reason,
        lr.Status,
        lr.ApprovedBy,
        lr.ApprovedDate,
        lr.Remarks,
        lr.IsCancelled
    FROM dbo.LeaveRequests lr
    WHERE lr.LeaveRequestId = @LeaveRequestId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_ApplyLeave
    @EmployeeId         INT,
    @LeaveTypeId        INT,
    @StartDate          DATE,
    @EndDate            DATE,
    @Reason             NVARCHAR(500),
    @NewLeaveRequestId  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.LeaveRequests (EmployeeId, LeaveTypeId, StartDate, EndDate, Reason, Status)
    VALUES (@EmployeeId, @LeaveTypeId, @StartDate, @EndDate, @Reason, N'Pending');

    SET @NewLeaveRequestId = SCOPE_IDENTITY();
    RETURN @NewLeaveRequestId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_UpdateLeave
    @LeaveRequestId INT,
    @LeaveTypeId    INT,
    @StartDate      DATE,
    @EndDate        DATE,
    @Reason         NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.LeaveRequests
    SET LeaveTypeId = @LeaveTypeId,
        StartDate = @StartDate,
        EndDate = @EndDate,
        Reason = @Reason,
        ModifiedDate = SYSUTCDATETIME()
    WHERE LeaveRequestId = @LeaveRequestId
      AND Status = N'Pending'
      AND IsCancelled = 0;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CancelLeave
    @LeaveRequestId INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.LeaveRequests
    SET IsCancelled = 1,
        Status = N'Cancelled',
        ModifiedDate = SYSUTCDATETIME()
    WHERE LeaveRequestId = @LeaveRequestId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_ApproveLeave
    @LeaveRequestId INT,
    @ApprovedBy     INT,
    @Remarks        NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.LeaveRequests
    SET Status = N'Approved',
        ApprovedBy = @ApprovedBy,
        ApprovedDate = SYSUTCDATETIME(),
        Remarks = @Remarks,
        ModifiedDate = SYSUTCDATETIME()
    WHERE LeaveRequestId = @LeaveRequestId
      AND IsCancelled = 0;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_RejectLeave
    @LeaveRequestId INT,
    @ApprovedBy     INT,
    @Remarks        NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.LeaveRequests
    SET Status = N'Rejected',
        ApprovedBy = @ApprovedBy,
        ApprovedDate = SYSUTCDATETIME(),
        Remarks = @Remarks,
        ModifiedDate = SYSUTCDATETIME()
    WHERE LeaveRequestId = @LeaveRequestId
      AND IsCancelled = 0;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetLeaveHistory
    @EmployeeId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        lr.LeaveRequestId,
        lr.EmployeeId,
        lr.LeaveTypeId,
        lr.StartDate,
        lr.EndDate,
        lr.TotalDays,
        lr.Reason,
        lr.Status,
        lr.Remarks
    FROM dbo.LeaveRequests lr
    WHERE lr.EmployeeId = @EmployeeId
      AND lr.IsCancelled = 0
    ORDER BY lr.StartDate DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetPendingLeaveRequests
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        lr.LeaveRequestId,
        lr.EmployeeId,
        lr.LeaveTypeId,
        lr.StartDate,
        lr.EndDate,
        lr.TotalDays,
        lr.Reason,
        lr.Status
    FROM dbo.LeaveRequests lr
    WHERE lr.Status = N'Pending'
      AND lr.IsCancelled = 0
    ORDER BY lr.StartDate;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetLeavesByDateRange
    @FromDate DATE,
    @ToDate   DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        lr.LeaveRequestId,
        lr.EmployeeId,
        lr.LeaveTypeId,
        lr.StartDate,
        lr.EndDate,
        lr.TotalDays,
        lr.Reason,
        lr.Status
    FROM dbo.LeaveRequests lr
    WHERE lr.IsCancelled = 0
      AND lr.StartDate >= @FromDate
      AND lr.EndDate <= @ToDate
    ORDER BY lr.StartDate;
END
GO

/* ===========================
   7) DASHBOARD
   =========================== */
CREATE OR ALTER PROCEDURE dbo.sp_GetDashboardData
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM dbo.Employees WHERE IsActive = 1) AS TotalEmployees,
        (SELECT COUNT(*) FROM dbo.Departments WHERE IsActive = 1) AS TotalDepartments,
        (SELECT COUNT(*) FROM dbo.LeaveRequests WHERE IsCancelled = 0) AS TotalLeaveRequests,
        (SELECT COUNT(*) FROM dbo.LeaveRequests WHERE Status = N'Pending' AND IsCancelled = 0) AS PendingLeaves,
        (SELECT COUNT(*) FROM dbo.LeaveRequests WHERE Status = N'Approved' AND IsCancelled = 0) AS ApprovedLeaves,
        (SELECT COUNT(*) FROM dbo.LeaveRequests WHERE Status = N'Rejected' AND IsCancelled = 0) AS RejectedLeaves,
        (SELECT COUNT(*) FROM dbo.LeaveTypes WHERE IsActive = 1) AS TotalLeaveTypes;
END
GO

/* ===========================
   8) REPORT STORED PROCEDURES
   =========================== */
CREATE OR ALTER PROCEDURE dbo.sp_EmployeeLeaveSummary
    @FromDate      DATE = NULL,
    @ToDate        DATE = NULL,
    @DepartmentId  INT = NULL,
    @EmployeeId    INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        e.EmployeeId,
        e.EmployeeCode,
        CONCAT(e.FirstName, N' ', ISNULL(e.LastName, N'')) AS EmployeeName,
        d.DepartmentName,
        lt.LeaveTypeName,
        lr.StartDate,
        lr.EndDate,
        lr.TotalDays,
        lr.Status
    FROM dbo.LeaveRequests lr
    INNER JOIN dbo.Employees e ON e.EmployeeId = lr.EmployeeId
    INNER JOIN dbo.Departments d ON d.DepartmentId = e.DepartmentId
    INNER JOIN dbo.LeaveTypes lt ON lt.LeaveTypeId = lr.LeaveTypeId
    WHERE lr.IsCancelled = 0
      AND (@FromDate IS NULL OR lr.StartDate >= @FromDate)
      AND (@ToDate IS NULL OR lr.EndDate <= @ToDate)
      AND (@DepartmentId IS NULL OR e.DepartmentId = @DepartmentId)
      AND (@EmployeeId IS NULL OR e.EmployeeId = @EmployeeId)
    ORDER BY lr.StartDate DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_MonthlyLeaveUtilization
    @Year INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @Year IS NULL SET @Year = YEAR(GETDATE());

    SELECT
        e.EmployeeId,
        e.EmployeeCode,
        CONCAT(e.FirstName, N' ', ISNULL(e.LastName, N'')) AS EmployeeName,
        d.DepartmentName,
        lt.LeaveTypeName,
        SUM(lr.TotalDays) AS TotalDays,
        MAX(lr.Status) AS Status
    FROM dbo.LeaveRequests lr
    INNER JOIN dbo.Employees e ON e.EmployeeId = lr.EmployeeId
    INNER JOIN dbo.Departments d ON d.DepartmentId = e.DepartmentId
    INNER JOIN dbo.LeaveTypes lt ON lt.LeaveTypeId = lr.LeaveTypeId
    WHERE lr.IsCancelled = 0
      AND YEAR(lr.StartDate) = @Year
    GROUP BY e.EmployeeId, e.EmployeeCode, e.FirstName, e.LastName, d.DepartmentName, lt.LeaveTypeName
    ORDER BY d.DepartmentName, EmployeeName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DepartmentWiseLeaveStatistics
    @FromDate DATE = NULL,
    @ToDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        d.DepartmentName,
        ISNULL(SUM(lr.TotalDays), 0) AS TotalLeaveDays
    FROM dbo.Departments d
    LEFT JOIN dbo.Employees e ON e.DepartmentId = d.DepartmentId AND e.IsActive = 1
    LEFT JOIN dbo.LeaveRequests lr ON lr.EmployeeId = e.EmployeeId
        AND lr.IsCancelled = 0
        AND (@FromDate IS NULL OR lr.StartDate >= @FromDate)
        AND (@ToDate IS NULL OR lr.EndDate <= @ToDate)
    GROUP BY d.DepartmentName
    ORDER BY d.DepartmentName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_PendingLeaveRequests
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        lr.LeaveRequestId,
        e.EmployeeCode,
        CONCAT(e.FirstName, N' ', ISNULL(e.LastName, N'')) AS EmployeeName,
        d.DepartmentName,
        lt.LeaveTypeName,
        lr.StartDate,
        lr.EndDate,
        lr.TotalDays,
        lr.Status
    FROM dbo.LeaveRequests lr
    INNER JOIN dbo.Employees e ON e.EmployeeId = lr.EmployeeId
    INNER JOIN dbo.Departments d ON d.DepartmentId = e.DepartmentId
    INNER JOIN dbo.LeaveTypes lt ON lt.LeaveTypeId = lr.LeaveTypeId
    WHERE lr.Status = N'Pending'
      AND lr.IsCancelled = 0
    ORDER BY lr.StartDate;
END
GO

-- Scheduler aliases (ReportSchedulerService)
CREATE OR ALTER PROCEDURE dbo.sp_GetDepartmentLeaveStats
    @FromDate DATE = NULL,
    @ToDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        d.DepartmentName,
        COUNT(DISTINCT e.EmployeeId) AS TotalEmployees,
        COUNT(lr.LeaveRequestId) AS TotalLeaves,
        CASE WHEN COUNT(DISTINCT e.EmployeeId) = 0 THEN 0
             ELSE CAST(ISNULL(SUM(lr.TotalDays), 0) AS DECIMAL(18,2)) / COUNT(DISTINCT e.EmployeeId)
        END AS AvgLeaveDaysPerEmployee
    FROM dbo.Departments d
    LEFT JOIN dbo.Employees e ON e.DepartmentId = d.DepartmentId AND e.IsActive = 1
    LEFT JOIN dbo.LeaveRequests lr ON lr.EmployeeId = e.EmployeeId
        AND lr.IsCancelled = 0
        AND (@FromDate IS NULL OR lr.StartDate >= @FromDate)
        AND (@ToDate IS NULL OR lr.EndDate <= @ToDate)
    GROUP BY d.DepartmentName
    ORDER BY d.DepartmentName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetMonthlyLeaveUtilization
    @Year INT,
    @Department NVARCHAR(200) = NULL,
    @EmployeeName NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        YEAR(lr.StartDate) AS [Year],
        MONTH(lr.StartDate) AS [Month],
        e.EmployeeId,
        CONCAT(e.FirstName, N' ', ISNULL(e.LastName, N'')) AS FullName,
        SUM(lr.TotalDays) AS LeaveDays
    FROM dbo.LeaveRequests lr
    INNER JOIN dbo.Employees e ON e.EmployeeId = lr.EmployeeId AND e.IsActive = 1
    INNER JOIN dbo.Departments d ON d.DepartmentId = e.DepartmentId
    WHERE YEAR(lr.StartDate) = @Year
      AND lr.IsCancelled = 0
      AND (@Department IS NULL OR d.DepartmentName = @Department)
      AND (@EmployeeName IS NULL OR CONCAT(e.FirstName, N' ', ISNULL(e.LastName, N'')) LIKE N'%' + @EmployeeName + N'%')
    GROUP BY YEAR(lr.StartDate), MONTH(lr.StartDate), e.EmployeeId, e.FirstName, e.LastName
    ORDER BY [Year], [Month], FullName;
END
GO

/* ===========================
   9) ANALYTICS STORED PROCEDURES
   =========================== */
CREATE OR ALTER PROCEDURE dbo.sp_LeaveTrendAnalysis
    @Year INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @Year IS NULL SET @Year = YEAR(GETDATE());

    SELECT
        MONTH(lr.StartDate) AS [Month],
        YEAR(lr.StartDate) AS [Year],
        COUNT(*) AS TotalLeaves,
        SUM(lr.TotalDays) AS TotalDays
    FROM dbo.LeaveRequests lr
    WHERE lr.IsCancelled = 0
      AND YEAR(lr.StartDate) = @Year
    GROUP BY YEAR(lr.StartDate), MONTH(lr.StartDate)
    ORDER BY [Month];
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DepartmentComparison
    @Year INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @Year IS NULL SET @Year = YEAR(GETDATE());

    SELECT
        d.DepartmentName,
        COUNT(lr.LeaveRequestId) AS TotalLeaves,
        ISNULL(SUM(lr.TotalDays), 0) AS TotalDays
    FROM dbo.Departments d
    LEFT JOIN dbo.Employees e ON e.DepartmentId = d.DepartmentId AND e.IsActive = 1
    LEFT JOIN dbo.LeaveRequests lr ON lr.EmployeeId = e.EmployeeId
        AND lr.IsCancelled = 0
        AND YEAR(lr.StartDate) = @Year
    GROUP BY d.DepartmentName
    ORDER BY d.DepartmentName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_FrequentLeavePattern
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (20)
        e.EmployeeCode,
        CONCAT(e.FirstName, N' ', ISNULL(e.LastName, N'')) AS EmployeeName,
        d.DepartmentName,
        COUNT(lr.LeaveRequestId) AS TotalLeaves,
        SUM(lr.TotalDays) AS TotalLeaveDays,
        CAST(AVG(CAST(lr.TotalDays AS DECIMAL(18,2))) AS DECIMAL(18,2)) AS AverageLeaveDays
    FROM dbo.LeaveRequests lr
    INNER JOIN dbo.Employees e ON e.EmployeeId = lr.EmployeeId
    INNER JOIN dbo.Departments d ON d.DepartmentId = e.DepartmentId
    WHERE lr.IsCancelled = 0
    GROUP BY e.EmployeeCode, e.FirstName, e.LastName, d.DepartmentName
    ORDER BY TotalLeaves DESC, TotalLeaveDays DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_ForecastLeaveUtilization
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH MonthlyAgg AS (
        SELECT
            d.DepartmentName,
            lt.LeaveTypeName,
            DATEFROMPARTS(YEAR(lr.StartDate), MONTH(lr.StartDate), 1) AS MonthStart,
            COUNT(*) AS LeaveCount,
            AVG(CAST(lr.TotalDays AS DECIMAL(18,2))) AS AvgDays
        FROM dbo.LeaveRequests lr
        INNER JOIN dbo.Employees e ON e.EmployeeId = lr.EmployeeId
        INNER JOIN dbo.Departments d ON d.DepartmentId = e.DepartmentId
        INNER JOIN dbo.LeaveTypes lt ON lt.LeaveTypeId = lr.LeaveTypeId
        WHERE lr.IsCancelled = 0
          AND lr.StartDate >= DATEADD(MONTH, -11, GETDATE())
        GROUP BY d.DepartmentName, lt.LeaveTypeName, DATEFROMPARTS(YEAR(lr.StartDate), MONTH(lr.StartDate), 1)
    )
    SELECT
        DepartmentName,
        LeaveTypeName,
        CAST(ROUND(AVG(LeaveCount), 0) AS INT) AS ForecastLeaveCount,
        CAST(AVG(AvgDays) AS DECIMAL(18,2)) AS ForecastAverageDays
    FROM MonthlyAgg
    GROUP BY DepartmentName, LeaveTypeName
    ORDER BY DepartmentName, LeaveTypeName;
END
GO

-- Legacy analytics names (Scripts/Analytics compatibility)
CREATE OR ALTER PROCEDURE dbo.sp_GetLeaveTrend
    @FromDate DATE,
    @ToDate   DATE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH MonthAgg AS (
        SELECT
            DATEFROMPARTS(YEAR(lr.StartDate), MONTH(lr.StartDate), 1) AS MonthStart,
            SUM(lr.TotalDays) AS TotalLeaveDays
        FROM dbo.LeaveRequests lr
        WHERE lr.IsCancelled = 0
          AND lr.StartDate >= @FromDate
          AND lr.StartDate <= @ToDate
        GROUP BY DATEFROMPARTS(YEAR(lr.StartDate), MONTH(lr.StartDate), 1)
    )
    SELECT
        MonthStart,
        TotalLeaveDays,
        LAG(TotalLeaveDays) OVER (ORDER BY MonthStart) AS PrevMonthLeaveDays,
        CASE
            WHEN LAG(TotalLeaveDays) OVER (ORDER BY MonthStart) IS NULL
              OR LAG(TotalLeaveDays) OVER (ORDER BY MonthStart) = 0 THEN NULL
            ELSE CAST((TotalLeaveDays - LAG(TotalLeaveDays) OVER (ORDER BY MonthStart)) * 100.0
                 / LAG(TotalLeaveDays) OVER (ORDER BY MonthStart) AS DECIMAL(9,2))
        END AS PercentChange
    FROM MonthAgg
    ORDER BY MonthStart;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetDepartmentComparison
    @FromDate DATE = NULL,
    @ToDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Year INT = YEAR(COALESCE(@FromDate, CAST(GETDATE() AS DATE)));
    EXEC dbo.sp_DepartmentComparison @Year = @Year;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetFrequentLeavePatterns
    @TopN INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@TopN)
        e.EmployeeId,
        CONCAT(e.FirstName, N' ', ISNULL(e.LastName, N'')) AS FullName,
        lt.LeaveTypeName AS LeaveType,
        COUNT(*) AS LeaveCount,
        SUM(lr.TotalDays) AS TotalLeaveDays
    FROM dbo.LeaveRequests lr
    INNER JOIN dbo.Employees e ON e.EmployeeId = lr.EmployeeId
    INNER JOIN dbo.LeaveTypes lt ON lt.LeaveTypeId = lr.LeaveTypeId
    WHERE lr.IsCancelled = 0
    GROUP BY e.EmployeeId, e.FirstName, e.LastName, lt.LeaveTypeName
    ORDER BY LeaveCount DESC, TotalLeaveDays DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetForecastedLeaveUtilization
    @MonthsToForecast INT = 3
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);

    ;WITH Last12 AS (
        SELECT
            DATEFROMPARTS(YEAR(StartDate), MONTH(StartDate), 1) AS MonthStart,
            SUM(TotalDays) AS LeaveDays
        FROM dbo.LeaveRequests
        WHERE IsCancelled = 0
          AND StartDate >= DATEADD(MONTH, -11, @Now)
          AND StartDate < DATEADD(MONTH, 1, @Now)
        GROUP BY DATEFROMPARTS(YEAR(StartDate), MONTH(StartDate), 1)
    )
    SELECT TOP (@MonthsToForecast)
        DATEADD(MONTH, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1, DATEADD(MONTH, 1, @Now)) AS ForecastMonth,
        CAST(AVG(LeaveDays) OVER () AS DECIMAL(18,2)) AS ForecastedLeaveDays
    FROM Last12
    ORDER BY ForecastMonth;
END
GO

/* ===========================
   10) AUDIT STORED PROCEDURES
   =========================== */
CREATE OR ALTER PROCEDURE dbo.sp_GetAuditHistory
AS
BEGIN
    SET NOCOUNT ON;
    SELECT AuditId, TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy, ChangedOn
    FROM dbo.AuditLogs
    ORDER BY ChangedOn DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetAuditLogById
    @AuditId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT AuditId, TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy, ChangedOn
    FROM dbo.AuditLogs
    WHERE AuditId = @AuditId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetAuditLogsByTable
    @TableName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT AuditId, TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy, ChangedOn
    FROM dbo.AuditLogs
    WHERE TableName = @TableName
    ORDER BY ChangedOn DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetAuditLogsByUser
    @ChangedBy NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT AuditId, TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy, ChangedOn
    FROM dbo.AuditLogs
    WHERE ChangedBy LIKE N'%' + @ChangedBy + N'%'
    ORDER BY ChangedOn DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetAuditByDate
    @FromDate DATETIME2,
    @ToDate   DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT AuditId, TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy, ChangedOn
    FROM dbo.AuditLogs
    WHERE ChangedOn >= @FromDate AND ChangedOn <= @ToDate
    ORDER BY ChangedOn DESC;
END
GO

/* ===========================
   11) OPTIONAL SEED DATA
   =========================== */
INSERT INTO dbo.Roles (RoleName, Description)
VALUES
    (N'Admin', N'Administrator with full reporting access'),
    (N'Employee', N'Standard employee user');
GO

-- Default admin credentials: admin / Admin@123
INSERT INTO dbo.Users (UserName, PasswordHash, Email, RoleId)
VALUES
    (N'admin', N'100000.sVmZ2ZK8pGxLpN3YzQ8wFg==.NIyIfjMBgb7RfEaZ7gSu+7aB0pHL43cs/z1+iyXRoKY=', N'admin@company.com', 1);
GO

INSERT INTO dbo.Departments (DepartmentName, DepartmentCode, Description)
VALUES
    (N'Human Resources', N'HR', N'HR department'),
    (N'Engineering', N'ENG', N'Software engineering'),
    (N'Finance', N'FIN', N'Finance and accounts');
GO

INSERT INTO dbo.LeaveTypes (LeaveTypeName, TotalDays, Description)
VALUES
    (N'Annual Leave', 20, N'Paid annual leave'),
    (N'Sick Leave', 10, N'Medical leave'),
    (N'Casual Leave', 5, N'Short personal leave'),
    (N'Maternity Leave', 90, N'Maternity leave'),
    (N'Unpaid Leave', 0, N'Unpaid time off');
GO

INSERT INTO dbo.Employees (
    EmployeeCode, FirstName, LastName, Gender, DateOfBirth, MobileNumber, Email,
    DepartmentId, ManagerId, JoinDate, Salary, Address
)
VALUES
    (N'EMP001', N'Alice', N'Johnson', N'Female', '1990-05-12', N'9000000001', N'alice@company.com', 2, NULL, '2020-01-15', 75000, N'City A'),
    (N'EMP002', N'Bob', N'Smith', N'Male', '1988-09-20', N'9000000002', N'bob@company.com', 2, 1, '2021-03-01', 65000, N'City B'),
    (N'EMP003', N'Carol', N'Lee', N'Female', '1992-11-03', N'9000000003', N'carol@company.com', 1, NULL, '2019-07-10', 55000, N'City C');
GO

INSERT INTO dbo.LeaveRequests (EmployeeId, LeaveTypeId, StartDate, EndDate, Reason, Status, ApprovedBy, ApprovedDate)
VALUES
    (1, 1, '2026-01-10', '2026-01-12', N'Family trip', N'Approved', 3, SYSUTCDATETIME()),
    (2, 2, '2026-02-05', '2026-02-06', N'Fever', N'Approved', 1, SYSUTCDATETIME()),
    (3, 3, '2026-03-01', '2026-03-01', N'Personal work', N'Pending', NULL, NULL);
GO

PRINT 'EmployeeLeaveDb deployed successfully via MASTER_DEPLOY.sql';
PRINT 'Next step: run Scripts\Security\SECURITY_DEPLOY.sql for DDM, RLS, roles, and monitoring.';
GO
