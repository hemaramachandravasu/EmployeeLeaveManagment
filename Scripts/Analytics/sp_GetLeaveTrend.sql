-- sp_GetLeaveTrend: Month-over-month leave days with percent change
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
