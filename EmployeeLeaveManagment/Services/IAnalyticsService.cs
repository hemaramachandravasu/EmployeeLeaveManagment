using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Services
{
    public interface IAnalyticsService
    {
        Task<IEnumerable<AnalyticsDto>> GetLeaveTrendAnalysisAsync(int? year = null);

        Task<IEnumerable<AnalyticsDto>> GetDepartmentComparisonAsync(int? year = null);

        Task<IEnumerable<AnalyticsDto>> GetFrequentLeavePatternAsync();

        Task<IEnumerable<AnalyticsDto>> GetForecastLeaveUtilizationAsync();
    }
}
