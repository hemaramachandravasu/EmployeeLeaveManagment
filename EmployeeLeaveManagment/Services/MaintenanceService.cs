using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Services;

public class MaintenanceService : IMaintenanceService
{
    private readonly IMaintenanceRepository _repository;

    public MaintenanceService(IMaintenanceRepository repository)
    {
        _repository = repository;
    }

    public Task<DatabaseHealthDashboardDto> GetHealthDashboardAsync()
        => _repository.GetHealthDashboardAsync();

    public Task<DatabaseSizeDto> GetDatabaseSizeAsync()
        => _repository.GetDatabaseSizeAsync();

    public Task<IEnumerable<MonthlyGrowthDto>> GetMonthlyGrowthAsync(int monthsBack = 12)
        => _repository.GetMonthlyGrowthAsync(monthsBack);

    public Task<IEnumerable<IndexHealthDto>> GetIndexHealthAsync(int minPageCount = 50)
        => _repository.GetIndexHealthAsync(minPageCount);

    public Task<IEnumerable<QueryPerformanceDto>> GetQueryPerformanceAsync(int topN = 25)
        => _repository.GetQueryPerformanceAsync(topN);

    public async Task<object> GetArchiveSummaryAsync(int daysBack = 90)
    {
        var (runs, totals) = await _repository.GetArchiveSummaryAsync(daysBack);
        return new { Runs = runs, Totals = totals };
    }

    public async Task<object> GetMaintenanceExecutionAsync(int daysBack = 90)
    {
        var (summary, detail) = await _repository.GetMaintenanceExecutionAsync(daysBack);
        return new { Summary = summary, Detail = detail };
    }

    public Task<IEnumerable<RetentionConfigDto>> GetRetentionConfigAsync()
        => _repository.GetRetentionConfigAsync();

    public Task<RetentionConfigDto?> UpdateRetentionAsync(UpdateRetentionRequestDto request)
        => _repository.UpdateRetentionAsync(request);

    public Task<byte[]> ExportMonthlyGrowthExcelAsync(int monthsBack = 12)
        => _repository.ExportMonthlyGrowthExcelAsync(monthsBack);

    public Task<byte[]> ExportIndexHealthExcelAsync(int minPageCount = 50)
        => _repository.ExportIndexHealthExcelAsync(minPageCount);

    public Task<byte[]> ExportQueryPerformanceExcelAsync(int topN = 25)
        => _repository.ExportQueryPerformanceExcelAsync(topN);

    public Task<byte[]> ExportArchiveSummaryExcelAsync(int daysBack = 90)
        => _repository.ExportArchiveSummaryExcelAsync(daysBack);

    public Task<byte[]> ExportMaintenanceExecutionExcelAsync(int daysBack = 90)
        => _repository.ExportMaintenanceExecutionExcelAsync(daysBack);

    public Task<string> ExportMonthlyGrowthCsvAsync(int monthsBack = 12)
        => _repository.ExportMonthlyGrowthCsvAsync(monthsBack);

    public Task<string> ExportIndexHealthCsvAsync(int minPageCount = 50)
        => _repository.ExportIndexHealthCsvAsync(minPageCount);

    public Task<string> ExportQueryPerformanceCsvAsync(int topN = 25)
        => _repository.ExportQueryPerformanceCsvAsync(topN);

    public Task<string> ExportArchiveSummaryCsvAsync(int daysBack = 90)
        => _repository.ExportArchiveSummaryCsvAsync(daysBack);

    public Task<string> ExportMaintenanceExecutionCsvAsync(int daysBack = 90)
        => _repository.ExportMaintenanceExecutionCsvAsync(daysBack);
}
