-- sp_GetForecastedLeaveUtilization: simple moving average forecast based on last 12 months
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
