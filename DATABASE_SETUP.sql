-- SQL Script: Create EmployeeLeaveDb
-- DEPRECATED: Use MASTER_DEPLOY.sql in the project root instead.
-- That script includes the full schema, all stored procedures, audit, analytics, and seed data.
--
-- Run in SQL Server SSMS against your SQL Server instance.
-- No sample data - schema only (legacy)

IF DB_ID('EmployeeLeaveDb') IS NULL
BEGIN
	CREATE DATABASE EmployeeLeaveDb;
END
GO

USE EmployeeLeaveDb;
GO

-- Departments
IF OBJECT_ID('dbo.Departments', 'U') IS NOT NULL DROP TABLE dbo.Departments;
CREATE TABLE dbo.Departments (
	DepartmentId INT IDENTITY(1,1) PRIMARY KEY,
	DepartmentName NVARCHAR(200) NOT NULL,
	CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- Employees (soft delete via IsDeleted)
IF OBJECT_ID('dbo.Employees', 'U') IS NOT NULL DROP TABLE dbo.Employees;
CREATE TABLE dbo.Employees (
	EmployeeId INT IDENTITY(1,1) PRIMARY KEY,
	FullName NVARCHAR(250) NOT NULL,
	DepartmentId INT NOT NULL REFERENCES dbo.Departments(DepartmentId),
	Email NVARCHAR(320) NULL,
	HireDate DATE NULL,
	IsDeleted BIT NOT NULL DEFAULT(0),
	CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- Leaves
IF OBJECT_ID('dbo.Leaves', 'U') IS NOT NULL DROP TABLE dbo.Leaves;
CREATE TABLE dbo.Leaves (
	LeaveId INT IDENTITY(1,1) PRIMARY KEY,
	EmployeeId INT NOT NULL REFERENCES dbo.Employees(EmployeeId),
	FromDate DATE NOT NULL,
	ToDate DATE NOT NULL,
	LeaveType NVARCHAR(100) NOT NULL,
	CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- LeaveRequests
IF OBJECT_ID('dbo.LeaveRequests', 'U') IS NOT NULL DROP TABLE dbo.LeaveRequests;
CREATE TABLE dbo.LeaveRequests (
	RequestId INT IDENTITY(1,1) PRIMARY KEY,
	EmployeeId INT NOT NULL REFERENCES dbo.Employees(EmployeeId),
	FromDate DATE NOT NULL,
	ToDate DATE NOT NULL,
	LeaveType NVARCHAR(100) NOT NULL,
	Status NVARCHAR(50) NOT NULL DEFAULT('Pending'),
	RequestedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
	ProcessedAt DATETIME2 NULL
);
GO

-- Indexes
CREATE NONCLUSTERED INDEX IX_Employees_DepartmentId ON dbo.Employees(DepartmentId) INCLUDE (FullName, Email, IsDeleted);
CREATE NONCLUSTERED INDEX IX_Employees_FullName ON dbo.Employees(FullName) WHERE IsDeleted = 0;
CREATE NONCLUSTERED INDEX IX_Leaves_EmployeeId_FromDate ON dbo.Leaves(EmployeeId, FromDate) INCLUDE (ToDate, LeaveType);
CREATE NONCLUSTERED INDEX IX_Leaves_FromDate ON dbo.Leaves(FromDate) INCLUDE (EmployeeId, ToDate);
CREATE NONCLUSTERED INDEX IX_LeaveRequests_Status_FromDate ON dbo.LeaveRequests(Status, FromDate) INCLUDE (ToDate, EmployeeId, LeaveType);
CREATE NONCLUSTERED INDEX IX_Departments_DepartmentName ON dbo.Departments(DepartmentName);
GO

-- Stored Procedures
CREATE OR ALTER PROCEDURE dbo.sp_GetEmployeeLeaveSummary
	@FromDate DATE = NULL,
	@ToDate DATE = NULL,
	@Department NVARCHAR(200) = NULL,
	@EmployeeName NVARCHAR(250) = NULL
AS
BEGIN
	SET NOCOUNT ON;
	SELECT
		e.EmployeeId,
		e.FullName,
		d.DepartmentName,
		COUNT(l.LeaveId) AS TotalLeavesTaken,
		ISNULL(SUM(DATEDIFF(day, l.FromDate, l.ToDate) + 1), 0) AS TotalLeaveDays
	FROM dbo.Employees e
	LEFT JOIN dbo.Departments d ON e.DepartmentId = d.DepartmentId
	LEFT JOIN dbo.Leaves l ON l.EmployeeId = e.EmployeeId
		AND (@FromDate IS NULL OR l.FromDate >= @FromDate)
		AND (@ToDate IS NULL OR l.ToDate <= @ToDate)
	WHERE e.IsDeleted = 0
	  AND (@Department IS NULL OR d.DepartmentName = @Department)
	  AND (@EmployeeName IS NULL OR e.FullName LIKE '%' + @EmployeeName + '%')
	GROUP BY e.EmployeeId, e.FullName, d.DepartmentName
	ORDER BY e.FullName;
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
		YEAR(l.FromDate) AS [Year],
		MONTH(l.FromDate) AS [Month],
		e.EmployeeId,
		e.FullName,
		SUM(DATEDIFF(day, l.FromDate, l.ToDate) + 1) AS LeaveDays
	FROM dbo.Leaves l
	INNER JOIN dbo.Employees e ON e.EmployeeId = l.EmployeeId AND e.IsDeleted = 0
	INNER JOIN dbo.Departments d ON d.DepartmentId = e.DepartmentId
	WHERE YEAR(l.FromDate) = @Year
	  AND (@Department IS NULL OR d.DepartmentName = @Department)
	  AND (@EmployeeName IS NULL OR e.FullName LIKE '%' + @EmployeeName + '%')
	GROUP BY YEAR(l.FromDate), MONTH(l.FromDate), e.EmployeeId, e.FullName
	ORDER BY [Year], [Month], e.FullName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetDepartmentLeaveStats
	@FromDate DATE = NULL,
	@ToDate DATE = NULL
AS
BEGIN
	SET NOCOUNT ON;
	SELECT
		d.DepartmentName,
		COUNT(DISTINCT e.EmployeeId) AS TotalEmployees,
		COUNT(l.LeaveId) AS TotalLeaves,
		CASE WHEN COUNT(DISTINCT e.EmployeeId) = 0 THEN 0
			 ELSE CAST(ISNULL(SUM(DATEDIFF(day, l.FromDate, l.ToDate) + 1),0) AS DECIMAL(18,2)) / COUNT(DISTINCT e.EmployeeId)
		END AS AvgLeaveDaysPerEmployee
	FROM dbo.Departments d
	LEFT JOIN dbo.Employees e ON e.DepartmentId = d.DepartmentId AND e.IsDeleted = 0
	LEFT JOIN dbo.Leaves l ON l.EmployeeId = e.EmployeeId
		AND (@FromDate IS NULL OR l.FromDate >= @FromDate)
		AND (@ToDate IS NULL OR l.ToDate <= @ToDate)
	GROUP BY d.DepartmentName
	ORDER BY d.DepartmentName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetPendingLeaveRequests
	@FromDate DATE = NULL,
	@ToDate DATE = NULL,
	@Department NVARCHAR(200) = NULL,
	@EmployeeName NVARCHAR(250) = NULL
AS
BEGIN
	SET NOCOUNT ON;
	SELECT
		lr.RequestId,
		e.EmployeeId,
		e.FullName,
		d.DepartmentName,
		lr.FromDate,
		lr.ToDate,
		lr.LeaveType,
		lr.Status
	FROM dbo.LeaveRequests lr
	INNER JOIN dbo.Employees e ON e.EmployeeId = lr.EmployeeId AND e.IsDeleted = 0
	INNER JOIN dbo.Departments d ON d.DepartmentId = e.DepartmentId
	WHERE lr.Status = 'Pending'
	  AND (@FromDate IS NULL OR lr.FromDate >= @FromDate)
	  AND (@ToDate IS NULL OR lr.ToDate <= @ToDate)
	  AND (@Department IS NULL OR d.DepartmentName = @Department)
	  AND (@EmployeeName IS NULL OR e.FullName LIKE '%' + @EmployeeName + '%')
	ORDER BY lr.FromDate;
END
GO

-- Database created successfully
PRINT 'EmployeeLeaveDb created successfully with tables, indexes, and stored procedures.';
