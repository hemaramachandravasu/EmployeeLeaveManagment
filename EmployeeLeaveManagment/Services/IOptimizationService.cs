using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Services;

public interface IOptimizationService
{
    Task<PerformanceSummaryDto> GetPerformanceSummaryAsync();
    Task<IEnumerable<QueryExecutionStatDto>> GetQueryExecutionStatsAsync(int topN = 25);
    Task<IEnumerable<TableGrowthDto>> GetTableGrowthAsync();
    Task<IEnumerable<StorageUtilizationDto>> GetStorageUtilizationAsync();
    Task<IEnumerable<OptIndexHealthDto>> GetIndexHealthAsync(int minPageCount = 50);
    Task<IEnumerable<PartitionInfoDto>> GetPartitionInfoAsync(string? tableName = null);
    Task<OptHealthCheckDto> GetHealthCheckAsync();

    Task<byte[]> ExportPerformanceSummaryExcelAsync();
    Task<byte[]> ExportQueryExecutionStatsExcelAsync(int topN = 25);
    Task<byte[]> ExportTableGrowthExcelAsync();
    Task<byte[]> ExportStorageUtilizationExcelAsync();
    Task<byte[]> ExportIndexHealthExcelAsync(int minPageCount = 50);
    Task<byte[]> ExportPartitionInfoExcelAsync(string? tableName = null);

    Task<string> ExportPerformanceSummaryCsvAsync();
    Task<string> ExportQueryExecutionStatsCsvAsync(int topN = 25);
    Task<string> ExportTableGrowthCsvAsync();
    Task<string> ExportStorageUtilizationCsvAsync();
    Task<string> ExportIndexHealthCsvAsync(int minPageCount = 50);
    Task<string> ExportPartitionInfoCsvAsync(string? tableName = null);
}
