/*
  Task 2 report filter patch (EmployeeName + related filters).
  sqlcmd -S localhost -E -C -i Scripts\Database\Task2_Report_EmployeeName_Filter.sql
*/
USE EmployeeLeaveDb;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_EmployeeLeaveSummary
    @FromDate      DATE = NULL,
    @ToDate        DATE = NULL,
    @DepartmentId  INT = NULL,
    @EmployeeId    INT = NULL,
    @EmployeeName  NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NamePattern NVARCHAR(252) = NULL;
    IF @EmployeeName IS NOT NULL AND LTRIM(RTRIM(@EmployeeName)) <> N''
        SET @NamePattern = N'%' + LTRIM(RTRIM(@EmployeeName)) + N'%';

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
      AND (
            @NamePattern IS NULL
            OR e.FirstName LIKE @NamePattern
            OR e.LastName LIKE @NamePattern
            OR CONCAT(e.FirstName, N' ', ISNULL(e.LastName, N'')) LIKE @NamePattern
            OR e.EmployeeCode LIKE @NamePattern
          )
    ORDER BY lr.StartDate DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_MonthlyLeaveUtilization
    @Year          INT = NULL,
    @DepartmentId  INT = NULL,
    @EmployeeId    INT = NULL,
    @EmployeeName  NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @Year IS NULL SET @Year = YEAR(GETDATE());

    DECLARE @NamePattern NVARCHAR(252) = NULL;
    IF @EmployeeName IS NOT NULL AND LTRIM(RTRIM(@EmployeeName)) <> N''
        SET @NamePattern = N'%' + LTRIM(RTRIM(@EmployeeName)) + N'%';

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
      AND (@DepartmentId IS NULL OR e.DepartmentId = @DepartmentId)
      AND (@EmployeeId IS NULL OR e.EmployeeId = @EmployeeId)
      AND (
            @NamePattern IS NULL
            OR e.FirstName LIKE @NamePattern
            OR e.LastName LIKE @NamePattern
            OR CONCAT(e.FirstName, N' ', ISNULL(e.LastName, N'')) LIKE @NamePattern
            OR e.EmployeeCode LIKE @NamePattern
          )
    GROUP BY e.EmployeeId, e.EmployeeCode, e.FirstName, e.LastName, d.DepartmentName, lt.LeaveTypeName
    ORDER BY d.DepartmentName, EmployeeName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_PendingLeaveRequests
    @FromDate      DATE = NULL,
    @ToDate        DATE = NULL,
    @DepartmentId  INT = NULL,
    @EmployeeId    INT = NULL,
    @EmployeeName  NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NamePattern NVARCHAR(252) = NULL;
    IF @EmployeeName IS NOT NULL AND LTRIM(RTRIM(@EmployeeName)) <> N''
        SET @NamePattern = N'%' + LTRIM(RTRIM(@EmployeeName)) + N'%';

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
      AND (@FromDate IS NULL OR lr.StartDate >= @FromDate)
      AND (@ToDate IS NULL OR lr.EndDate <= @ToDate)
      AND (@DepartmentId IS NULL OR e.DepartmentId = @DepartmentId)
      AND (@EmployeeId IS NULL OR e.EmployeeId = @EmployeeId)
      AND (
            @NamePattern IS NULL
            OR e.FirstName LIKE @NamePattern
            OR e.LastName LIKE @NamePattern
            OR CONCAT(e.FirstName, N' ', ISNULL(e.LastName, N'')) LIKE @NamePattern
            OR e.EmployeeCode LIKE @NamePattern
          )
    ORDER BY lr.StartDate;
END
GO
