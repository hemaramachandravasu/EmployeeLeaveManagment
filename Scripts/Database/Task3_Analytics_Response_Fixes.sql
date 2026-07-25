/*
  Task 3 analytics SP response fixes (MoM %, averages, year).
  sqlcmd -S localhost -E -C -i Scripts\Database\Task3_Analytics_Response_Fixes.sql
*/
USE EmployeeLeaveDb;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_LeaveTrendAnalysis
    @Year INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @Year IS NULL SET @Year = YEAR(GETDATE());

    ;WITH Monthly AS (
        SELECT
            MONTH(lr.StartDate) AS [Month],
            YEAR(lr.StartDate) AS [Year],
            COUNT(*) AS TotalLeaves,
            SUM(lr.TotalDays) AS TotalDays
        FROM dbo.LeaveRequests lr
        WHERE lr.IsCancelled = 0
          AND YEAR(lr.StartDate) = @Year
        GROUP BY YEAR(lr.StartDate), MONTH(lr.StartDate)
    )
    SELECT
        m.[Year],
        m.[Month],
        m.TotalLeaves,
        m.TotalDays,
        CASE
            WHEN LAG(m.TotalDays) OVER (ORDER BY m.[Month]) IS NULL
              OR LAG(m.TotalDays) OVER (ORDER BY m.[Month]) = 0 THEN NULL
            ELSE CAST(
                (m.TotalDays - LAG(m.TotalDays) OVER (ORDER BY m.[Month])) * 100.0
                / LAG(m.TotalDays) OVER (ORDER BY m.[Month]) AS DECIMAL(18,2)
            )
        END AS MonthOverMonthChangePercent
    FROM Monthly m
    ORDER BY m.[Month];
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DepartmentComparison
    @Year INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @Year IS NULL SET @Year = YEAR(GETDATE());

    SELECT
        @Year AS [Year],
        d.DepartmentName,
        COUNT(lr.LeaveRequestId) AS TotalLeaves,
        ISNULL(SUM(lr.TotalDays), 0) AS TotalDays,
        CASE
            WHEN COUNT(lr.LeaveRequestId) = 0 THEN CAST(0 AS DECIMAL(18,2))
            ELSE CAST(ISNULL(SUM(lr.TotalDays), 0) AS DECIMAL(18,2)) / COUNT(lr.LeaveRequestId)
        END AS AverageLeaveDays
    FROM dbo.Departments d
    LEFT JOIN dbo.Employees e ON e.DepartmentId = d.DepartmentId AND e.IsActive = 1
    LEFT JOIN dbo.LeaveRequests lr ON lr.EmployeeId = e.EmployeeId
        AND lr.IsCancelled = 0
        AND YEAR(lr.StartDate) = @Year
    GROUP BY d.DepartmentName
    ORDER BY d.DepartmentName;
END
GO
