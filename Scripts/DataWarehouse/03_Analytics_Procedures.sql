/*
    Predictive analytics and dashboard feed stored procedures
    Database: EmployeeLeaveDW
*/
USE EmployeeLeaveDW;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- Forecasted leave demand: next 3 months by department (rolling 12-month average)
CREATE OR ALTER PROCEDURE dbo.sp_ForecastLeaveDemand_Department
    @AsOfDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @AsOfDate IS NULL
        SET @AsOfDate = CAST(SYSUTCDATETIME() AS DATE);

    ;WITH MonthlyHistory AS
    (
        SELECT
            f.DepartmentKey,
            dd.[Year],
            dd.[Month],
            YearMonth = dd.[Year] * 100 + dd.[Month],
            LeaveCount = COUNT(*),
            TotalDays = SUM(f.DaysApproved)
        FROM dbo.FactLeaveRequests f
        INNER JOIN dbo.DimDate dd ON dd.DateKey = f.StartDateKey
        WHERE dd.[Date] >= DATEADD(MONTH, -12, @AsOfDate)
          AND dd.[Date] < @AsOfDate
          AND f.IsCancelled = 0
        GROUP BY f.DepartmentKey, dd.[Year], dd.[Month]
    ),
    RollingAvg AS
    (
        SELECT
            DepartmentKey,
            YearMonth,
            LeaveCount,
            Rolling12MonthAvg = AVG(CAST(LeaveCount AS DECIMAL(18,2)))
                OVER (PARTITION BY DepartmentKey ORDER BY YearMonth ROWS BETWEEN 11 PRECEDING AND CURRENT ROW)
        FROM MonthlyHistory
    ),
    LatestAvg AS
    (
        SELECT DepartmentKey, ForecastAvg = Rolling12MonthAvg
        FROM
        (
            SELECT DepartmentKey, YearMonth, Rolling12MonthAvg,
                   ROW_NUMBER() OVER (PARTITION BY DepartmentKey ORDER BY YearMonth DESC) AS rn
            FROM RollingAvg
        ) x
        WHERE rn = 1
    ),
    ForecastMonths AS
    (
        SELECT 1 AS MonthOffset UNION ALL SELECT 2 UNION ALL SELECT 3
    )
    SELECT
        d.DepartmentName,
        ForecastYear = YEAR(DATEADD(MONTH, fm.MonthOffset, @AsOfDate)),
        ForecastMonth = MONTH(DATEADD(MONTH, fm.MonthOffset, @AsOfDate)),
        ForecastMonthName = DATENAME(MONTH, DATEADD(MONTH, fm.MonthOffset, @AsOfDate)),
        ForecastedLeaveCount = CAST(ROUND(ISNULL(la.ForecastAvg, 0), 0) AS INT),
        ForecastedLeaveDays = CAST(ROUND(ISNULL(la.ForecastAvg, 0) * 2, 0) AS INT),
        Methodology = N'Rolling 12-month average'
    FROM dbo.DimDepartment d
    CROSS JOIN ForecastMonths fm
    LEFT JOIN LatestAvg la ON la.DepartmentKey = d.DepartmentKey
    WHERE d.EffectiveTo = '9999-12-31 23:59:59'
    ORDER BY d.DepartmentName, ForecastYear, ForecastMonth;
END
GO

-- Employee burnout risk indicator
CREATE OR ALTER PROCEDURE dbo.sp_EmployeeBurnoutRisk
    @LookbackDays INT = 180
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AsOfDate DATE = CAST(SYSUTCDATETIME() AS DATE);

    ;WITH ApprovedLeaves AS
    (
        SELECT
            f.EmployeeKey,
            e.EmployeeId,
            e.EmployeeCode,
            e.FullName,
            d.DepartmentName,
            dd.[Date],
            f.DaysApproved,
            f.StartDateKey,
            f.EndDateKey
        FROM dbo.FactLeaveRequests f
        INNER JOIN dbo.DimEmployee e ON e.EmployeeKey = f.EmployeeKey AND e.EffectiveTo = '9999-12-31 23:59:59'
        INNER JOIN dbo.DimDepartment d ON d.DepartmentKey = f.DepartmentKey AND d.EffectiveTo = '9999-12-31 23:59:59'
        INNER JOIN dbo.DimDate dd ON dd.DateKey = f.StartDateKey
        WHERE dd.[Date] >= DATEADD(DAY, -@LookbackDays, @AsOfDate)
          AND f.IsCancelled = 0
          AND f.[Status] = N'Approved'
          AND f.DaysApproved > 0
    ),
    EmployeeAgg AS
    (
        SELECT
            EmployeeKey,
            EmployeeId = MAX(EmployeeId),
            EmployeeCode = MAX(EmployeeCode),
            FullName = MAX(FullName),
            DepartmentName = MAX(DepartmentName),
            TotalLeaves = COUNT(*),
            TotalDays = SUM(DaysApproved),
            AvgDaysPerLeave = AVG(DaysApproved),
            MaxConsecutiveDays = MAX(DaysApproved)
        FROM ApprovedLeaves
        GROUP BY EmployeeKey
    ),
    Frequency AS
    (
        SELECT
            EmployeeKey,
            LeavesLast90Days = SUM(CASE WHEN [Date] >= DATEADD(DAY, -90, @AsOfDate) THEN 1 ELSE 0 END)
        FROM ApprovedLeaves
        GROUP BY EmployeeKey
    )
    SELECT
        a.EmployeeId,
        a.EmployeeCode,
        a.FullName AS EmployeeName,
        a.DepartmentName,
        a.TotalLeaves,
        a.TotalDays,
        a.AvgDaysPerLeave,
        a.MaxConsecutiveDays,
        ISNULL(f.LeavesLast90Days, 0) AS LeavesLast90Days,
        BurnoutRiskLevel =
            CASE
                WHEN a.MaxConsecutiveDays >= 10 OR (a.TotalLeaves >= 6 AND a.TotalDays >= 20) THEN N'High'
                WHEN a.TotalLeaves >= 4 OR ISNULL(f.LeavesLast90Days, 0) >= 3 THEN N'Medium'
                ELSE N'Low'
            END,
        RiskReason =
            CASE
                WHEN a.MaxConsecutiveDays >= 10 THEN N'Long consecutive leave block'
                WHEN a.TotalLeaves >= 6 AND a.TotalDays >= 20 THEN N'High frequency and volume'
                WHEN ISNULL(f.LeavesLast90Days, 0) >= 3 THEN N'Unusual recent frequency'
                WHEN a.TotalLeaves >= 4 THEN N'Elevated leave count'
                ELSE N'Within normal range'
            END
    FROM EmployeeAgg a
    LEFT JOIN Frequency f ON f.EmployeeKey = a.EmployeeKey
    ORDER BY
        CASE
            WHEN a.MaxConsecutiveDays >= 10 OR (a.TotalLeaves >= 6 AND a.TotalDays >= 20) THEN 1
            WHEN a.TotalLeaves >= 4 OR ISNULL(f.LeavesLast90Days, 0) >= 3 THEN 2
            ELSE 3
        END,
        a.TotalDays DESC;
END
GO

-- Peak leave period identification (months and weeks)
CREATE OR ALTER PROCEDURE dbo.sp_PeakLeavePeriods
    @LookbackYears INT = 3,
    @TopN INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AsOfDate DATE = CAST(SYSUTCDATETIME() AS DATE);

    ;WITH Base AS
    (
        SELECT
            dd.[Year],
            dd.[Month],
            dd.WeekOfYear,
            f.DaysApproved
        FROM dbo.FactLeaveRequests f
        INNER JOIN dbo.DimDate dd ON dd.DateKey = f.StartDateKey
        WHERE dd.[Date] >= DATEADD(YEAR, -@LookbackYears, @AsOfDate)
          AND f.IsCancelled = 0
          AND f.[Status] = N'Approved'
    ),
    Monthly AS
    (
        SELECT TOP (@TopN)
            PeriodType = N'Month',
            PeriodLabel = CONCAT([Year], N'-', FORMAT([Month], '00')),
            [Year],
            [Month],
            WeekOfYear = NULL,
            TotalLeaves = COUNT(*),
            TotalDays = SUM(DaysApproved)
        FROM Base
        GROUP BY [Year], [Month]
        ORDER BY COUNT(*) DESC, SUM(DaysApproved) DESC
    ),
    Weekly AS
    (
        SELECT TOP (@TopN)
            PeriodType = N'Week',
            PeriodLabel = CONCAT([Year], N'-W', FORMAT(WeekOfYear, '00')),
            [Year],
            [Month] = NULL,
            WeekOfYear,
            TotalLeaves = COUNT(*),
            TotalDays = SUM(DaysApproved)
        FROM Base
        GROUP BY [Year], WeekOfYear
        ORDER BY COUNT(*) DESC, SUM(DaysApproved) DESC
    )
    SELECT PeriodType, PeriodLabel, [Year], [Month], WeekOfYear, TotalLeaves, TotalDays
    FROM Monthly
    UNION ALL
    SELECT PeriodType, PeriodLabel, [Year], [Month], WeekOfYear, TotalLeaves, TotalDays
    FROM Weekly
    ORDER BY PeriodType, TotalLeaves DESC;
END
GO

-- Dashboard feed: month-over-month leave trend
CREATE OR ALTER PROCEDURE dbo.sp_DW_MonthOverMonthTrend
    @Year INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Year IS NULL
        SET @Year = YEAR(SYSUTCDATETIME());

    ;WITH Monthly AS
    (
        SELECT
            dd.[Year],
            dd.[Month],
            dd.MonthName,
            TotalLeaves = COUNT(*),
            TotalDays = SUM(f.DaysApproved),
            ApprovedDays = SUM(f.DaysApproved),
            RejectedDays = SUM(f.DaysRejected)
        FROM dbo.FactLeaveRequests f
        INNER JOIN dbo.DimDate dd ON dd.DateKey = f.StartDateKey
        WHERE dd.[Year] = @Year
          AND f.IsCancelled = 0
        GROUP BY dd.[Year], dd.[Month], dd.MonthName
    )
    SELECT
        [Year],
        [Month],
        MonthName,
        TotalLeaves,
        TotalDays,
        ApprovedDays,
        RejectedDays,
        PrevMonthLeaves = LAG(TotalLeaves) OVER (ORDER BY [Month]),
        MomLeaveChangePct =
            CASE
                WHEN LAG(TotalLeaves) OVER (ORDER BY [Month]) IS NULL OR LAG(TotalLeaves) OVER (ORDER BY [Month]) = 0 THEN NULL
                ELSE CAST((TotalLeaves - LAG(TotalLeaves) OVER (ORDER BY [Month])) * 100.0
                     / LAG(TotalLeaves) OVER (ORDER BY [Month]) AS DECIMAL(10,2))
            END
    FROM Monthly
    ORDER BY [Month];
END
GO

-- Dashboard feed: department utilization heatmap
CREATE OR ALTER PROCEDURE dbo.sp_DW_DepartmentUtilizationHeatmap
    @Year INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Year IS NULL
        SET @Year = YEAR(SYSUTCDATETIME());

    SELECT
        d.DepartmentName,
        dd.[Month],
        dd.MonthName,
        TotalLeaves = COUNT(*),
        TotalDays = SUM(f.DaysApproved),
        UtilizationScore = CAST(SUM(f.DaysApproved) * 100.0 / NULLIF(COUNT(DISTINCT f.EmployeeKey), 0) AS DECIMAL(10,2))
    FROM dbo.FactLeaveRequests f
    INNER JOIN dbo.DimDepartment d ON d.DepartmentKey = f.DepartmentKey AND d.EffectiveTo = '9999-12-31 23:59:59'
    INNER JOIN dbo.DimDate dd ON dd.DateKey = f.StartDateKey
    WHERE dd.[Year] = @Year
      AND f.IsCancelled = 0
      AND f.[Status] = N'Approved'
    GROUP BY d.DepartmentName, dd.[Month], dd.MonthName
    ORDER BY d.DepartmentName, dd.[Month];
END
GO

-- Dashboard feed: top 5 leave types by volume (current year)
CREATE OR ALTER PROCEDURE dbo.sp_DW_TopLeaveTypesByVolume
    @Year INT = NULL,
    @TopN INT = 5
AS
BEGIN
    SET NOCOUNT ON;

    IF @Year IS NULL
        SET @Year = YEAR(SYSUTCDATETIME());

    SELECT TOP (@TopN)
        lt.LeaveTypeName,
        TotalRequests = COUNT(*),
        TotalDays = SUM(f.DaysApproved),
        ApprovedRequests = SUM(CASE WHEN f.[Status] = N'Approved' THEN 1 ELSE 0 END),
        RejectedRequests = SUM(CASE WHEN f.[Status] = N'Rejected' THEN 1 ELSE 0 END)
    FROM dbo.FactLeaveRequests f
    INNER JOIN dbo.DimLeaveType lt ON lt.LeaveTypeKey = f.LeaveTypeKey AND lt.EffectiveTo = '9999-12-31 23:59:59'
    INNER JOIN dbo.DimDate dd ON dd.DateKey = f.StartDateKey
    WHERE dd.[Year] = @Year
      AND f.IsCancelled = 0
    GROUP BY lt.LeaveTypeName
    ORDER BY COUNT(*) DESC, SUM(f.DaysApproved) DESC;
END
GO

PRINT 'Analytics and dashboard feed procedures created successfully.';
GO
