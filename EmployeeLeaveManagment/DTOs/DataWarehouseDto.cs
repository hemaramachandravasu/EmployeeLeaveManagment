namespace EmployeeLeaveManagment.DTOs;

public class ForecastDemandDto
{
    public string DepartmentName { get; set; } = string.Empty;
    public int ForecastYear { get; set; }
    public int ForecastMonth { get; set; }
    public string ForecastMonthName { get; set; } = string.Empty;
    public int ForecastedLeaveCount { get; set; }
    public int ForecastedLeaveDays { get; set; }
    public string Methodology { get; set; } = string.Empty;
}

public class BurnoutRiskDto
{
    public int EmployeeId { get; set; }
    public string EmployeeCode { get; set; } = string.Empty;
    public string EmployeeName { get; set; } = string.Empty;
    public string DepartmentName { get; set; } = string.Empty;
    public int TotalLeaves { get; set; }
    public decimal TotalDays { get; set; }
    public decimal AvgDaysPerLeave { get; set; }
    public decimal MaxConsecutiveDays { get; set; }
    public int LeavesLast90Days { get; set; }
    public string BurnoutRiskLevel { get; set; } = string.Empty;
    public string RiskReason { get; set; } = string.Empty;
}

public class PeakPeriodDto
{
    public string PeriodType { get; set; } = string.Empty;
    public string PeriodLabel { get; set; } = string.Empty;
    public int? Year { get; set; }
    public int? Month { get; set; }
    public int? WeekOfYear { get; set; }
    public int TotalLeaves { get; set; }
    public decimal TotalDays { get; set; }
}

public class MomTrendDto
{
    public int Year { get; set; }
    public int Month { get; set; }
    public string MonthName { get; set; } = string.Empty;
    public int TotalLeaves { get; set; }
    public decimal TotalDays { get; set; }
    public decimal ApprovedDays { get; set; }
    public decimal RejectedDays { get; set; }
    public int? PrevMonthLeaves { get; set; }
    public decimal? MomLeaveChangePct { get; set; }
}

public class DepartmentHeatmapDto
{
    public string DepartmentName { get; set; } = string.Empty;
    public int Month { get; set; }
    public string MonthName { get; set; } = string.Empty;
    public int TotalLeaves { get; set; }
    public decimal TotalDays { get; set; }
    public decimal? UtilizationScore { get; set; }
}

public class TopLeaveTypeDto
{
    public string LeaveTypeName { get; set; } = string.Empty;
    public int TotalRequests { get; set; }
    public decimal TotalDays { get; set; }
    public int ApprovedRequests { get; set; }
    public int RejectedRequests { get; set; }
}

public class EtlRunLogDto
{
    public int EtlRunId { get; set; }
    public string ProcessName { get; set; } = string.Empty;
    public DateTime StartTime { get; set; }
    public DateTime? EndTime { get; set; }
    public string Status { get; set; } = string.Empty;
    public int? RowsInserted { get; set; }
    public int? RowsUpdated { get; set; }
    public string? ErrorMessage { get; set; }
}

public class DataWarehouseFilterDto
{
    public int? Year { get; set; }
    public int? LookbackDays { get; set; }
    public int? LookbackYears { get; set; }
    public int? TopN { get; set; }
    public DateTime? AsOfDate { get; set; }
}
