-- Combined deployment script (No session context).
-- DEPRECATED: Use MASTER_DEPLOY.sql in the project root instead.
-- Run this on your development DB to create audit table, triggers, analytics stored procedures and archival objects.

-- 1) Audit table
IF OBJECT_ID('dbo.AuditLogs','U') IS NULL
BEGIN
CREATE TABLE dbo.AuditLogs
(
	AuditId BIGINT IDENTITY(1,1) PRIMARY KEY,
	TableName SYSNAME NOT NULL,
	KeyValue NVARCHAR(200) NOT NULL,
	Operation CHAR(1) NOT NULL,
	OldValues NVARCHAR(MAX) NULL,
	NewValues NVARCHAR(MAX) NULL,
	ChangedBy NVARCHAR(400) NULL,
	ChangedAt DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
	TransactionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID()
);

CREATE INDEX IX_AuditLogs_TableDate ON dbo.AuditLogs(TableName, ChangedAt);

CREATE INDEX IX_AuditLogs_ChangedAt ON dbo.AuditLogs(ChangedAt);
END
GO

-- 2) Triggers (Employees)
IF OBJECT_ID('dbo.trg_Employees_Audit','TR') IS NOT NULL
	DROP TRIGGER dbo.trg_Employees_Audit;
GO

CREATE TRIGGER dbo.trg_Employees_Audit
ON dbo.Employees
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
	SET NOCOUNT ON;

	INSERT INTO dbo.AuditLogs (TableName, KeyValue, Operation, OldValues, NewValues, ChangedBy)
	SELECT
		'Employees',
		CONCAT('Employee:', ISNULL(CONVERT(NVARCHAR(50), COALESCE(i.EmployeeId, d.EmployeeId)), '')),
		CASE 
			WHEN i.EmployeeId IS NOT NULL AND d.EmployeeId IS NULL THEN 'I'
			WHEN i.EmployeeId IS NOT NULL AND d.EmployeeId IS NOT NULL THEN 'U'
			WHEN i.EmployeeId IS NULL AND d.EmployeeId IS NOT NULL THEN 'D'
			ELSE 'U' END,
		CASE WHEN d.EmployeeId IS NULL THEN NULL ELSE (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
		CASE WHEN i.EmployeeId IS NULL THEN NULL ELSE (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
		CONCAT(SUSER_SNAME(), ' | ', APP_NAME(), ' | ', HOST_NAME())
	FROM inserted i
	FULL OUTER JOIN deleted d ON i.EmployeeId = d.EmployeeId;
END
GO

-- 3) Triggers (Leaves)
IF OBJECT_ID('dbo.trg_Leaves_Audit','TR') IS NOT NULL
	DROP TRIGGER dbo.trg_Leaves_Audit;
GO

CREATE TRIGGER dbo.trg_Leaves_Audit
ON dbo.Leaves
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
	SET NOCOUNT ON;

	INSERT INTO dbo.AuditLogs (TableName, KeyValue, Operation, OldValues, NewValues, ChangedBy)
	SELECT
		'Leaves',
		CONCAT('Leave:', ISNULL(CONVERT(NVARCHAR(50), COALESCE(i.LeaveId, d.LeaveId)), '')),
		CASE 
			WHEN i.LeaveId IS NOT NULL AND d.LeaveId IS NULL THEN 'I'
			WHEN i.LeaveId IS NOT NULL AND d.LeaveId IS NOT NULL THEN 'U'
			WHEN i.LeaveId IS NULL AND d.LeaveId IS NOT NULL THEN 'D'
			ELSE 'U' END,
		CASE WHEN d.LeaveId IS NULL THEN NULL ELSE (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
		CASE WHEN i.LeaveId IS NULL THEN NULL ELSE (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
		CONCAT(SUSER_SNAME(), ' | ', APP_NAME(), ' | ', HOST_NAME())
	FROM inserted i
	FULL OUTER JOIN deleted d ON i.LeaveId = d.LeaveId;
END
GO

-- 4) Analytics stored procedures
-- sp_GetLeaveTrend
IF OBJECT_ID('dbo.sp_GetLeaveTrend','P') IS NOT NULL
	DROP PROCEDURE dbo.sp_GetLeaveTrend;
GO
CREATE PROCEDURE dbo.sp_GetLeaveTrend
	@FromDate DATE,
	@ToDate DATE
AS
BEGIN
	SET NOCOUNT ON;
	;WITH MonthAgg AS (
		SELECT
			DATEFROMPARTS(YEAR(l.FromDate), MONTH(l.FromDate), 1) AS MonthStart,
			SUM(DATEDIFF(day, l.FromDate, l.ToDate) + 1) AS TotalLeaveDays
		FROM dbo.Leaves l
		WHERE l.FromDate >= @FromDate AND l.FromDate <= @ToDate
		GROUP BY DATEFROMPARTS(YEAR(l.FromDate), MONTH(l.FromDate), 1)
	)
	SELECT
		MonthStart,
		TotalLeaveDays,
		LAG(TotalLeaveDays) OVER (ORDER BY MonthStart) AS PrevMonthLeaveDays,
		CASE WHEN LAG(TotalLeaveDays) OVER (ORDER BY MonthStart) = 0 OR LAG(TotalLeaveDays) OVER (ORDER BY MonthStart) IS NULL THEN NULL
			 ELSE CAST((TotalLeaveDays - LAG(TotalLeaveDays) OVER (ORDER BY MonthStart)) * 100.0 / LAG(TotalLeaveDays) OVER (ORDER BY MonthStart) AS DECIMAL(9,2))
		END AS PercentChange
	FROM MonthAgg
	ORDER BY MonthStart;
END
GO

-- sp_GetDepartmentComparison
IF OBJECT_ID('dbo.sp_GetDepartmentComparison','P') IS NOT NULL
	DROP PROCEDURE dbo.sp_GetDepartmentComparison;
GO
CREATE PROCEDURE dbo.sp_GetDepartmentComparison
	@FromDate DATE = NULL,
	@ToDate DATE = NULL
AS
BEGIN
	SET NOCOUNT ON;
	SELECT d.DepartmentId, d.DepartmentName,
		COUNT(DISTINCT e.EmployeeId) AS TotalEmployees,
		COUNT(l.LeaveId) AS TotalLeaves,
		ISNULL(SUM(DATEDIFF(day, l.FromDate, l.ToDate) + 1),0) AS TotalLeaveDays,
		CASE WHEN COUNT(DISTINCT e.EmployeeId)=0 THEN 0 ELSE CAST(ISNULL(SUM(DATEDIFF(day, l.FromDate, l.ToDate) + 1),0) AS DECIMAL(18,2))/COUNT(DISTINCT e.EmployeeId) END AS AvgLeaveDaysPerEmployee
	FROM dbo.Departments d
	LEFT JOIN dbo.Employees e ON e.DepartmentId = d.DepartmentId
	LEFT JOIN dbo.Leaves l ON l.EmployeeId = e.EmployeeId
		AND (@FromDate IS NULL OR l.FromDate >= @FromDate)
		AND (@ToDate IS NULL OR l.ToDate <= @ToDate)
	GROUP BY d.DepartmentId, d.DepartmentName
	ORDER BY d.DepartmentName;
END
GO

-- sp_GetFrequentLeavePatterns
IF OBJECT_ID('dbo.sp_GetFrequentLeavePatterns','P') IS NOT NULL
	DROP PROCEDURE dbo.sp_GetFrequentLeavePatterns;
GO
CREATE PROCEDURE dbo.sp_GetFrequentLeavePatterns
	@TopN INT = 20
AS
BEGIN
	SET NOCOUNT ON;
	SELECT TOP (@TopN)
		e.EmployeeId, e.FullName, l.LeaveType,
		COUNT(*) AS LeaveCount,
		SUM(DATEDIFF(day, l.FromDate, l.ToDate)+1) AS TotalLeaveDays
	FROM dbo.Leaves l
	JOIN dbo.Employees e ON e.EmployeeId = l.EmployeeId
	GROUP BY e.EmployeeId, e.FullName, l.LeaveType
	ORDER BY LeaveCount DESC, TotalLeaveDays DESC;
END
GO

-- sp_GetForecastedLeaveUtilization
IF OBJECT_ID('dbo.sp_GetForecastedLeaveUtilization','P') IS NOT NULL
	DROP PROCEDURE dbo.sp_GetForecastedLeaveUtilization;
GO
CREATE PROCEDURE dbo.sp_GetForecastedLeaveUtilization
	@MonthsToForecast INT = 3
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Now DATE = DATEADD(day, 1-DAY(GETDATE()), CAST(GETDATE() AS DATE));

	;WITH Last12 AS (
		SELECT DATEFROMPARTS(YEAR(FromDate), MONTH(FromDate), 1) AS MonthStart,
			   SUM(DATEDIFF(day, FromDate, ToDate)+1) AS LeaveDays
		FROM dbo.Leaves
		WHERE FromDate >= DATEADD(month, -11, @Now) AND FromDate < DATEADD(month, 1, @Now)
		GROUP BY DATEFROMPARTS(YEAR(FromDate), MONTH(FromDate), 1)
	)
	SELECT TOP (@MonthsToForecast)
		DATEADD(month, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1, DATEADD(month, 1, @Now)) AS ForecastMonth,
		CAST(AVG(LeaveDays) OVER () AS DECIMAL(18,2)) AS ForecastedLeaveDays
	FROM Last12
	ORDER BY ForecastMonth;
END
GO

-- 5) LeavesArchive creation
IF OBJECT_ID('dbo.LeavesArchive','U') IS NULL
BEGIN
	SELECT TOP (0) *
	INTO dbo.LeavesArchive
	FROM dbo.Leaves;

	ALTER TABLE dbo.LeavesArchive
	ADD ArchivedAt DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME();
END
GO

-- 6) Archival script: move closed leaves older than 3 years
DECLARE @RetentionYears INT = 3;

BEGIN TRAN;

	INSERT INTO dbo.LeavesArchive WITH (TABLOCK)
	SELECT *, SYSUTCDATETIME() AS ArchivedAt
	FROM dbo.Leaves
	WHERE FromDate < DATEADD(year, -@RetentionYears, GETDATE()) AND Status = 'Closed';

	DELETE L
	FROM dbo.Leaves L
	WHERE L.FromDate < DATEADD(year, -@RetentionYears, GETDATE()) AND L.Status = 'Closed';

COMMIT TRAN;
GO

-- End of combined deploy script
