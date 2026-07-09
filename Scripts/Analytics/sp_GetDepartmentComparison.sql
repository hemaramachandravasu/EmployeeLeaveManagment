-- sp_GetDepartmentComparison: compare departments on leaves and averages
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
