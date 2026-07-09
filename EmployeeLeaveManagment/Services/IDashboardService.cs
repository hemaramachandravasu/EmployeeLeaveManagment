using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Services;

public interface IDashboardService
{
    Task<DashboardDto> GetDashboardDataAsync();
    Task<IEnumerable<DepartmentLeaveFeedDto>> GetDepartmentLeaveCountsAsync(int? year);
    Task<IEnumerable<MonthlyTrendFeedDto>> GetMonthlyUtilizationTrendAsync(int? year);
}
