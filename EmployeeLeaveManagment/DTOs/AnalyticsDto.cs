using System.Text.Json.Serialization;

namespace EmployeeLeaveManagment.DTOs;

public class LeaveTrendDto
{
    public int Year { get; set; }
    public int Month { get; set; }
    public int TotalLeaves { get; set; }
    public int TotalDays { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public decimal? MonthOverMonthChangePercent { get; set; }
}

public class DepartmentComparisonDto
{
    public int Year { get; set; }
    public string DepartmentName { get; set; } = string.Empty;
    public int TotalLeaves { get; set; }
    public int TotalDays { get; set; }
    public decimal AverageLeaveDays { get; set; }
}

public class FrequentLeavePatternDto
{
    public string EmployeeCode { get; set; } = string.Empty;
    public string EmployeeName { get; set; } = string.Empty;
    public string DepartmentName { get; set; } = string.Empty;
    public int TotalLeaves { get; set; }
    public int TotalDays { get; set; }
    public decimal AverageLeaveDays { get; set; }
}

public class ForecastLeaveUtilizationDto
{
    public string DepartmentName { get; set; } = string.Empty;
    public string LeaveType { get; set; } = string.Empty;
    public int ForecastLeaveCount { get; set; }
    public decimal ForecastAverageDays { get; set; }
}

/// <summary>Legacy shared shape kept for internal/scheduler compatibility.</summary>
public class AnalyticsDto
{
    public string? Category { get; set; }
    public string? DepartmentName { get; set; }
    public string? EmployeeCode { get; set; }
    public string? EmployeeName { get; set; }
    public string? LeaveType { get; set; }
    public int TotalLeaves { get; set; }
    public int TotalDays { get; set; }
    public decimal AverageLeaveDays { get; set; }
    public int Month { get; set; }
    public int Year { get; set; }
    public decimal? MonthOverMonthChangePercent { get; set; }
}
