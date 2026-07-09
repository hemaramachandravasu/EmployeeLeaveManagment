-- sp_GetFrequentLeavePatterns: top N employees by leave count
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
