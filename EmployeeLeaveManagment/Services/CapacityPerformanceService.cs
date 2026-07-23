using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Services;

public class CapacityPerformanceService : ICapacityPerformanceService
{
    private readonly ICapacityPerformanceRepository _repository;

    public CapacityPerformanceService(ICapacityPerformanceRepository repository)
    {
        _repository = repository;
    }

    public Task<CapPerfDashboardDto> GetDashboardAsync() => _repository.GetDashboardAsync();
    public Task<IEnumerable<CapacityGrowthTrendDto>> GetGrowthTrendsAsync(int daysBack = 90) => _repository.GetGrowthTrendsAsync(daysBack);
    public Task<IEnumerable<TableSizeDto>> GetTableSizesAsync() => _repository.GetTableSizesAsync();
    public Task<IEnumerable<CapStorageFileDto>> GetStorageUtilizationAsync() => _repository.GetStorageUtilizationAsync();
    public Task<IEnumerable<FilegroupUtilizationDto>> GetFilegroupUtilizationAsync() => _repository.GetFilegroupUtilizationAsync();
    public Task<CapacityForecastDto> ForecastCapacityAsync(int lookbackDays = 90) => _repository.ForecastCapacityAsync(lookbackDays);
    public Task<CapacityPlanningSummaryDto> GetCapacityPlanningSummaryAsync() => _repository.GetCapacityPlanningSummaryAsync();
    public Task<IEnumerable<SlowQueryStatDto>> GetSlowQueryStatisticsAsync(int topN = 25) => _repository.GetSlowQueryStatisticsAsync(topN);
    public Task<IEnumerable<QueryExecutionTrendDto>> GetQueryExecutionTrendsAsync(int hoursBack = 24) => _repository.GetQueryExecutionTrendsAsync(hoursBack);
    public Task<IEnumerable<IndexUtilizationDto>> GetIndexUtilizationAsync(bool includeUnusedOnly = false) => _repository.GetIndexUtilizationAsync(includeUnusedOnly);
    public Task<IEnumerable<ActiveSessionDto>> GetActiveSessionsAsync() => _repository.GetActiveSessionsAsync();
    public Task<IEnumerable<WaitStatisticDto>> GetWaitStatisticsAsync(int topN = 25) => _repository.GetWaitStatisticsAsync(topN);
    public Task<ResourceConsumptionDto> GetResourceConsumptionAsync() => _repository.GetResourceConsumptionAsync();
    public Task<IEnumerable<CapPerfAlertDto>> GetAlertHistoryAsync(int daysBack = 30, bool unacknowledgedOnly = false, string? alertType = null)
        => _repository.GetAlertHistoryAsync(daysBack, unacknowledgedOnly, alertType);
    public Task RunAllAlertsAsync() => _repository.RunAllAlertsAsync();
    public Task<CapPerfAlertDto?> AcknowledgeAlertAsync(int alertId) => _repository.AcknowledgeAlertAsync(alertId);
    public Task<IEnumerable<CapacityAlertThresholdDto>> GetThresholdsAsync() => _repository.GetThresholdsAsync();
    public Task<CapacityAlertThresholdDto?> UpdateThresholdAsync(string thresholdCode, UpdateThresholdRequestDto request)
        => _repository.UpdateThresholdAsync(thresholdCode, request);
    public Task CaptureMetricsAsync() => _repository.CaptureMetricsAsync();
    public Task<byte[]> ExportCapacitySummaryExcelAsync() => _repository.ExportCapacitySummaryExcelAsync();
    public Task<byte[]> ExportSqlPerformanceExcelAsync(int topN = 25) => _repository.ExportSqlPerformanceExcelAsync(topN);
    public Task<byte[]> ExportStorageExcelAsync() => _repository.ExportStorageExcelAsync();
    public Task<byte[]> ExportResourceExcelAsync() => _repository.ExportResourceExcelAsync();
    public Task<byte[]> ExportAlertHistoryExcelAsync(int daysBack = 30) => _repository.ExportAlertHistoryExcelAsync(daysBack);
    public Task<string> ExportCapacitySummaryCsvAsync() => _repository.ExportCapacitySummaryCsvAsync();
    public Task<string> ExportSqlPerformanceCsvAsync(int topN = 25) => _repository.ExportSqlPerformanceCsvAsync(topN);
    public Task<string> ExportStorageCsvAsync() => _repository.ExportStorageCsvAsync();
    public Task<string> ExportResourceCsvAsync() => _repository.ExportResourceCsvAsync();
    public Task<string> ExportAlertHistoryCsvAsync(int daysBack = 30) => _repository.ExportAlertHistoryCsvAsync(daysBack);
}
