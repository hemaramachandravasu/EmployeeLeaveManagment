using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Data;

public interface IDashboardRepository
{
    Task<DashboardDto> GetDashboardDataAsync();
    Task<IEnumerable<DepartmentLeaveFeedDto>> GetDepartmentLeaveCountsAsync(int? year);
    Task<IEnumerable<MonthlyTrendFeedDto>> GetMonthlyUtilizationTrendAsync(int? year);
}
