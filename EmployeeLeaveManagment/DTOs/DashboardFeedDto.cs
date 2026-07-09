namespace EmployeeLeaveManagment.DTOs;

public class DepartmentLeaveFeedDto
{
    public string DepartmentName { get; set; } = string.Empty;
    public int TotalLeaves { get; set; }
    public int TotalDays { get; set; }
}

public class MonthlyTrendFeedDto
{
    public int Month { get; set; }
    public int Year { get; set; }
    public int TotalLeaves { get; set; }
    public int TotalDays { get; set; }
}
