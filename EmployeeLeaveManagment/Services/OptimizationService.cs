using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Services;

public class OptimizationService : IOptimizationService
{
    private readonly IOptimizationRepository _repository;

    public OptimizationService(IOptimizationRepository repository)
    {
        _repository = repository;
    }

    public Task<PerformanceSummaryDto> GetPerformanceSummaryAsync()
        => _repository.GetPerformanceSummaryAsync();

    public Task<IEnumerable<QueryExecutionStatDto>> GetQueryExecutionStatsAsync(int topN = 25)
        => _repository.GetQueryExecutionStatsAsync(topN);

    public Task<IEnumerable<TableGrowthDto>> GetTableGrowthAsync()
        => _repository.GetTableGrowthAsync();

    public Task<IEnumerable<StorageUtilizationDto>> GetStorageUtilizationAsync()
        => _repository.GetStorageUtilizationAsync();

    public Task<IEnumerable<OptIndexHealthDto>> GetIndexHealthAsync(int minPageCount = 50)
        => _repository.GetIndexHealthAsync(minPageCount);

    public Task<IEnumerable<PartitionInfoDto>> GetPartitionInfoAsync(string? tableName = null)
        => _repository.GetPartitionInfoAsync(tableName);

    public Task<OptHealthCheckDto> GetHealthCheckAsync()
        => _repository.GetHealthCheckAsync();

    public Task<byte[]> ExportPerformanceSummaryExcelAsync()
        => _repository.ExportPerformanceSummaryExcelAsync();

    public Task<byte[]> ExportQueryExecutionStatsExcelAsync(int topN = 25)
        => _repository.ExportQueryExecutionStatsExcelAsync(topN);

    public Task<byte[]> ExportTableGrowthExcelAsync()
        => _repository.ExportTableGrowthExcelAsync();

    public Task<byte[]> ExportStorageUtilizationExcelAsync()
        => _repository.ExportStorageUtilizationExcelAsync();

    public Task<byte[]> ExportIndexHealthExcelAsync(int minPageCount = 50)
        => _repository.ExportIndexHealthExcelAsync(minPageCount);

    public Task<byte[]> ExportPartitionInfoExcelAsync(string? tableName = null)
        => _repository.ExportPartitionInfoExcelAsync(tableName);

    public Task<string> ExportPerformanceSummaryCsvAsync()
        => _repository.ExportPerformanceSummaryCsvAsync();

    public Task<string> ExportQueryExecutionStatsCsvAsync(int topN = 25)
        => _repository.ExportQueryExecutionStatsCsvAsync(topN);

    public Task<string> ExportTableGrowthCsvAsync()
        => _repository.ExportTableGrowthCsvAsync();

    public Task<string> ExportStorageUtilizationCsvAsync()
        => _repository.ExportStorageUtilizationCsvAsync();

    public Task<string> ExportIndexHealthCsvAsync(int minPageCount = 50)
        => _repository.ExportIndexHealthCsvAsync(minPageCount);

    public Task<string> ExportPartitionInfoCsvAsync(string? tableName = null)
        => _repository.ExportPartitionInfoCsvAsync(tableName);
}
