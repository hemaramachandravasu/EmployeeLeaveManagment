using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;

namespace EmployeeLeaveManagment.Services
{
 
    public class AnalyticsService : IAnalyticsService
    {
        private readonly IAnalyticsRepository _analyticsRepository;

        public AnalyticsService(IAnalyticsRepository analyticsRepository)
        {
            _analyticsRepository = analyticsRepository;
        }

        public async Task<IEnumerable<AnalyticsDto>> GetLeaveTrendAnalysisAsync(int? year = null)
        {
            return await _analyticsRepository.GetLeaveTrendAnalysisAsync(year);
        }

        public async Task<IEnumerable<AnalyticsDto>> GetDepartmentComparisonAsync(int? year = null)
        {
            return await _analyticsRepository.GetDepartmentComparisonAsync(year);
        }

        public async Task<IEnumerable<AnalyticsDto>> GetFrequentLeavePatternAsync()
        {
            return await _analyticsRepository.GetFrequentLeavePatternAsync();
        }

        public async Task<IEnumerable<AnalyticsDto>> GetForecastLeaveUtilizationAsync()
        {
            return await _analyticsRepository.GetForecastLeaveUtilizationAsync();
        }
    }
}