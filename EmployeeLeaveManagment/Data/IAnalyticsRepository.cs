using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Data;

public interface IAnalyticsRepository
{
    Task<IEnumerable<LeaveTrendDto>> GetLeaveTrendAnalysisAsync(int? year = null);

    Task<IEnumerable<DepartmentComparisonDto>> GetDepartmentComparisonAsync(int? year = null);

    Task<IEnumerable<FrequentLeavePatternDto>> GetFrequentLeavePatternAsync();

    Task<IEnumerable<ForecastLeaveUtilizationDto>> GetForecastLeaveUtilizationAsync();
}
