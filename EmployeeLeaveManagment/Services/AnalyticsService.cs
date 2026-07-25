using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Services;

public class AnalyticsService : IAnalyticsService
{
    private readonly IAnalyticsRepository _analyticsRepository;

    public AnalyticsService(IAnalyticsRepository analyticsRepository)
    {
        _analyticsRepository = analyticsRepository;
    }

    public Task<IEnumerable<LeaveTrendDto>> GetLeaveTrendAnalysisAsync(int? year = null)
        => _analyticsRepository.GetLeaveTrendAnalysisAsync(year);

    public Task<IEnumerable<DepartmentComparisonDto>> GetDepartmentComparisonAsync(int? year = null)
        => _analyticsRepository.GetDepartmentComparisonAsync(year);

    public Task<IEnumerable<FrequentLeavePatternDto>> GetFrequentLeavePatternAsync()
        => _analyticsRepository.GetFrequentLeavePatternAsync();

    public Task<IEnumerable<ForecastLeaveUtilizationDto>> GetForecastLeaveUtilizationAsync()
        => _analyticsRepository.GetForecastLeaveUtilizationAsync();
}
