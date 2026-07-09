using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Helpers;

public static class ReportFilterValidator
{
    public static string? Validate(ReportFilterDto? filter, bool requireBody = true)
    {
        if (filter == null)
            return requireBody ? "Report filter is required in the request body." : null;

        if (filter.FromDate.HasValue && filter.ToDate.HasValue && filter.FromDate > filter.ToDate)
            return "FromDate must be on or before ToDate.";

        if (filter.Year.HasValue && (filter.Year < 2000 || filter.Year > 2100))
            return "Year must be between 2000 and 2100.";

        if (filter.Month.HasValue && (filter.Month < 1 || filter.Month > 12))
            return "Month must be between 1 and 12.";

        if (filter.DepartmentId.HasValue && filter.DepartmentId <= 0)
            return "DepartmentId must be greater than zero.";

        if (filter.EmployeeId.HasValue && filter.EmployeeId <= 0)
            return "EmployeeId must be greater than zero.";

        return null;
    }
}
