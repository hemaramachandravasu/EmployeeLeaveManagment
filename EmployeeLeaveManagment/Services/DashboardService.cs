using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Services;

public class DashboardService : IDashboardService
{
    private readonly IDashboardRepository _dashboardRepository;

    public DashboardService(IDashboardRepository dashboardRepository)
    {
        _dashboardRepository = dashboardRepository;
    }

    public Task<DashboardDto> GetDashboardDataAsync() =>
        _dashboardRepository.GetDashboardDataAsync();

    public Task<IEnumerable<DepartmentLeaveFeedDto>> GetDepartmentLeaveCountsAsync(int? year) =>
        _dashboardRepository.GetDepartmentLeaveCountsAsync(year);

    public Task<IEnumerable<MonthlyTrendFeedDto>> GetMonthlyUtilizationTrendAsync(int? year) =>
        _dashboardRepository.GetMonthlyUtilizationTrendAsync(year);
}
