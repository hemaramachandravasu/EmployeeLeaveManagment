using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Data;

public interface ICapacityPerformanceRepository
{
    Task<CapPerfDashboardDto> GetDashboardAsync();
    Task<IEnumerable<CapacityGrowthTrendDto>> GetGrowthTrendsAsync(int daysBack = 90);
    Task<IEnumerable<TableSizeDto>> GetTableSizesAsync();
    Task<IEnumerable<CapStorageFileDto>> GetStorageUtilizationAsync();
    Task<IEnumerable<FilegroupUtilizationDto>> GetFilegroupUtilizationAsync();
    Task<CapacityForecastDto> ForecastCapacityAsync(int lookbackDays = 90);
    Task<CapacityPlanningSummaryDto> GetCapacityPlanningSummaryAsync();

    Task<IEnumerable<SlowQueryStatDto>> GetSlowQueryStatisticsAsync(int topN = 25);
    Task<IEnumerable<QueryExecutionTrendDto>> GetQueryExecutionTrendsAsync(int hoursBack = 24);
    Task<IEnumerable<IndexUtilizationDto>> GetIndexUtilizationAsync(bool includeUnusedOnly = false);
    Task<IEnumerable<ActiveSessionDto>> GetActiveSessionsAsync();
    Task<IEnumerable<WaitStatisticDto>> GetWaitStatisticsAsync(int topN = 25);
    Task<ResourceConsumptionDto> GetResourceConsumptionAsync();

    Task<IEnumerable<CapPerfAlertDto>> GetAlertHistoryAsync(int daysBack = 30, bool unacknowledgedOnly = false, string? alertType = null);
    Task RunAllAlertsAsync();
    Task<CapPerfAlertDto?> AcknowledgeAlertAsync(int alertId);
    Task<IEnumerable<CapacityAlertThresholdDto>> GetThresholdsAsync();
    Task<CapacityAlertThresholdDto?> UpdateThresholdAsync(string thresholdCode, UpdateThresholdRequestDto request);

    Task CaptureMetricsAsync();

    Task<byte[]> ExportCapacitySummaryExcelAsync();
    Task<byte[]> ExportSqlPerformanceExcelAsync(int topN = 25);
    Task<byte[]> ExportStorageExcelAsync();
    Task<byte[]> ExportResourceExcelAsync();
    Task<byte[]> ExportAlertHistoryExcelAsync(int daysBack = 30);

    Task<string> ExportCapacitySummaryCsvAsync();
    Task<string> ExportSqlPerformanceCsvAsync(int topN = 25);
    Task<string> ExportStorageCsvAsync();
    Task<string> ExportResourceCsvAsync();
    Task<string> ExportAlertHistoryCsvAsync(int daysBack = 30);
}
