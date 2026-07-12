using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Data;

public interface IMaintenanceRepository
{
    Task<DatabaseHealthDashboardDto> GetHealthDashboardAsync();
    Task<DatabaseSizeDto> GetDatabaseSizeAsync();
    Task<IEnumerable<MonthlyGrowthDto>> GetMonthlyGrowthAsync(int monthsBack = 12);
    Task<IEnumerable<IndexHealthDto>> GetIndexHealthAsync(int minPageCount = 50);
    Task<IEnumerable<QueryPerformanceDto>> GetQueryPerformanceAsync(int topN = 25);
    Task<(IEnumerable<ArchiveSummaryDto> Runs, IEnumerable<ArchiveEntityStatDto> Totals)> GetArchiveSummaryAsync(int daysBack = 90);
    Task<(IEnumerable<MaintenanceExecutionSummaryDto> Summary, IEnumerable<MaintenanceHistoryDto> Detail)> GetMaintenanceExecutionAsync(int daysBack = 90);
    Task<IEnumerable<RetentionConfigDto>> GetRetentionConfigAsync();
    Task<RetentionConfigDto?> UpdateRetentionAsync(UpdateRetentionRequestDto request);
    Task<byte[]> ExportMonthlyGrowthExcelAsync(int monthsBack = 12);
    Task<byte[]> ExportIndexHealthExcelAsync(int minPageCount = 50);
    Task<byte[]> ExportQueryPerformanceExcelAsync(int topN = 25);
    Task<byte[]> ExportArchiveSummaryExcelAsync(int daysBack = 90);
    Task<byte[]> ExportMaintenanceExecutionExcelAsync(int daysBack = 90);
    Task<string> ExportMonthlyGrowthCsvAsync(int monthsBack = 12);
    Task<string> ExportIndexHealthCsvAsync(int minPageCount = 50);
    Task<string> ExportQueryPerformanceCsvAsync(int topN = 25);
    Task<string> ExportArchiveSummaryCsvAsync(int daysBack = 90);
    Task<string> ExportMaintenanceExecutionCsvAsync(int daysBack = 90);
}
