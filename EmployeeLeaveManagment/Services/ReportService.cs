using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using Microsoft.Extensions.Configuration;

namespace EmployeeLeaveManagment.Services;

public class ReportService : IReportService
{
    private readonly IReportRepository _reportRepository;
    private readonly ICacheService _cacheService;
    private readonly int _cacheMinutes;

    public ReportService(IReportRepository reportRepository, ICacheService cacheService, IConfiguration configuration)
    {
        _reportRepository = reportRepository;
        _cacheService = cacheService;
        _cacheMinutes = Math.Max(1, configuration.GetValue("Reporting:CacheMinutes", 10));
    }

    // Test-friendly overload when configuration is not required.
    public ReportService(IReportRepository reportRepository, ICacheService cacheService)
        : this(reportRepository, cacheService, new ConfigurationBuilder().Build())
    {
    }

    public async Task<IEnumerable<ReportDto>> GetEmployeeLeaveSummaryAsync(ReportFilterDto filter)
    {
        string cacheKey = BuildCacheKey("employee-summary", filter);
        if (_cacheService.TryGetValue(cacheKey, out List<ReportDto>? cached) && cached != null)
            return cached;

        var result = (await _reportRepository.GetEmployeeLeaveSummaryAsync(filter)).ToList();
        _cacheService.Set(cacheKey, result, _cacheMinutes);
        return result;
    }

    public async Task<IEnumerable<ReportDto>> GetMonthlyLeaveUtilizationAsync(ReportFilterDto filter)
    {
        string cacheKey = BuildCacheKey("monthly-utilization", filter);
        if (_cacheService.TryGetValue(cacheKey, out List<ReportDto>? cached) && cached != null)
            return cached;

        var result = (await _reportRepository.GetMonthlyLeaveUtilizationAsync(filter)).ToList();
        _cacheService.Set(cacheKey, result, _cacheMinutes);
        return result;
    }

    public async Task<IEnumerable<ReportDto>> GetDepartmentLeaveStatisticsAsync(ReportFilterDto filter)
    {
        // Highest-frequency report — always cache.
        string cacheKey = BuildCacheKey("department-statistics", filter);
        if (_cacheService.TryGetValue(cacheKey, out List<ReportDto>? cached) && cached != null)
            return cached;

        var result = (await _reportRepository.GetDepartmentLeaveStatisticsAsync(filter)).ToList();
        _cacheService.Set(cacheKey, result, _cacheMinutes);
        return result;
    }

    public async Task<IEnumerable<ReportDto>> GetPendingLeaveRequestsAsync(ReportFilterDto? filter = null)
    {
        // Pending lists change often; skip cache for freshness.
        return await _reportRepository.GetPendingLeaveRequestsAsync(filter);
    }

    public Task<byte[]> ExportEmployeeLeaveSummaryExcelAsync(ReportFilterDto filter)
        => _reportRepository.ExportEmployeeLeaveSummaryExcelAsync(filter);

    public Task<byte[]> ExportDepartmentStatisticsExcelAsync(ReportFilterDto filter)
        => _reportRepository.ExportDepartmentStatisticsExcelAsync(filter);

    public Task<string> ExportEmployeeLeaveSummaryCsvAsync(ReportFilterDto filter)
        => _reportRepository.ExportEmployeeLeaveSummaryCsvAsync(filter);

    public Task<string> ExportDepartmentStatisticsCsvAsync(ReportFilterDto filter)
        => _reportRepository.ExportDepartmentStatisticsCsvAsync(filter);

    private static string BuildCacheKey(string reportName, ReportFilterDto filter)
    {
        return string.Join(':',
            "report",
            reportName,
            filter.FromDate?.ToString("yyyy-MM-dd") ?? "-",
            filter.ToDate?.ToString("yyyy-MM-dd") ?? "-",
            filter.DepartmentId?.ToString() ?? "-",
            filter.EmployeeId?.ToString() ?? "-",
            string.IsNullOrWhiteSpace(filter.EmployeeName) ? "-" : filter.EmployeeName.Trim().ToLowerInvariant(),
            filter.Year?.ToString() ?? "-",
            filter.Month?.ToString() ?? "-");
    }
}
