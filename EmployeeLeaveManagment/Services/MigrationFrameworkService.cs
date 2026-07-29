using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Services;

public interface IMigrationFrameworkService
{
    Task<IEnumerable<SchemaMigrationDto>> GetMigrationHistoryAsync(string? status = null, int topN = 100);
    Task<SchemaMigrationDto> ApplyMigrationAsync(ApplyMigrationRequestDto request);
    Task<SchemaMigrationDto> RollbackMigrationAsync(string? versionNumber = null);
    Task<SchemaMigrationDto> ApplySampleMigrationAsync();
    Task<IEnumerable<MetaModuleDto>> GetModulesAsync(bool activeOnly = true);
    Task<IEnumerable<MetaConfigCategoryDto>> GetConfigCategoriesAsync(string? moduleCode = null, bool activeOnly = true);
    Task<IEnumerable<MetaLookupValueDto>> GetLookupValuesAsync(string categoryCode, bool activeOnly = true);
    Task<IEnumerable<MetaAuditCategoryDto>> GetAuditCategoriesAsync(bool activeOnly = true);
    Task<MetaLookupValueDto> UpsertLookupAsync(UpsertLookupRequestDto request);
    Task<object> RefreshMetadataAsync();
    Task<MetadataUsageReportDto> GetMetadataUsageAsync();
    Task<ValidationRunResultDto> RunValidationAsync(int? balanceYear = null);
    Task<IEnumerable<ValidationSummaryDto>> GetValidationSummaryAsync(int daysBack = 30);
    Task<IEnumerable<ValidationIssueDto>> GetValidationIssuesAsync(int daysBack = 30, bool unresolvedOnly = false, string? checkCode = null);
    Task<DataQualityDashboardDto> GetDataQualityDashboardAsync();
    Task<ValidationIssueDto?> ResolveValidationIssueAsync(long validationId, string resolvedBy);
    Task<byte[]> ExportMigrationHistoryExcelAsync(int topN = 100);
    Task<byte[]> ExportValidationSummaryExcelAsync(int daysBack = 30);
    Task<byte[]> ExportValidationIssuesExcelAsync(int daysBack = 30);
    Task<byte[]> ExportDataQualityExcelAsync();
    Task<byte[]> ExportMetadataUsageExcelAsync();
    Task<string> ExportMigrationHistoryCsvAsync(int topN = 100);
    Task<string> ExportValidationSummaryCsvAsync(int daysBack = 30);
    Task<string> ExportValidationIssuesCsvAsync(int daysBack = 30);
    Task<string> ExportDataQualityCsvAsync();
    Task<string> ExportMetadataUsageCsvAsync();
}

public class MigrationFrameworkService : IMigrationFrameworkService
{
    private readonly IMigrationFrameworkRepository _repository;

    public MigrationFrameworkService(IMigrationFrameworkRepository repository)
    {
        _repository = repository;
    }

    public Task<IEnumerable<SchemaMigrationDto>> GetMigrationHistoryAsync(string? status = null, int topN = 100)
        => _repository.GetMigrationHistoryAsync(status, topN);
    public Task<SchemaMigrationDto> ApplyMigrationAsync(ApplyMigrationRequestDto request)
        => _repository.ApplyMigrationAsync(request);
    public Task<SchemaMigrationDto> RollbackMigrationAsync(string? versionNumber = null)
        => _repository.RollbackMigrationAsync(versionNumber);
    public Task<SchemaMigrationDto> ApplySampleMigrationAsync()
        => _repository.ApplySampleMigrationAsync();
    public Task<IEnumerable<MetaModuleDto>> GetModulesAsync(bool activeOnly = true)
        => _repository.GetModulesAsync(activeOnly);
    public Task<IEnumerable<MetaConfigCategoryDto>> GetConfigCategoriesAsync(string? moduleCode = null, bool activeOnly = true)
        => _repository.GetConfigCategoriesAsync(moduleCode, activeOnly);
    public Task<IEnumerable<MetaLookupValueDto>> GetLookupValuesAsync(string categoryCode, bool activeOnly = true)
        => _repository.GetLookupValuesAsync(categoryCode, activeOnly);
    public Task<IEnumerable<MetaAuditCategoryDto>> GetAuditCategoriesAsync(bool activeOnly = true)
        => _repository.GetAuditCategoriesAsync(activeOnly);
    public Task<MetaLookupValueDto> UpsertLookupAsync(UpsertLookupRequestDto request)
        => _repository.UpsertLookupAsync(request);
    public Task<object> RefreshMetadataAsync() => _repository.RefreshMetadataAsync();
    public Task<MetadataUsageReportDto> GetMetadataUsageAsync() => _repository.GetMetadataUsageAsync();
    public Task<ValidationRunResultDto> RunValidationAsync(int? balanceYear = null)
        => _repository.RunValidationAsync(balanceYear);
    public Task<IEnumerable<ValidationSummaryDto>> GetValidationSummaryAsync(int daysBack = 30)
        => _repository.GetValidationSummaryAsync(daysBack);
    public Task<IEnumerable<ValidationIssueDto>> GetValidationIssuesAsync(int daysBack = 30, bool unresolvedOnly = false, string? checkCode = null)
        => _repository.GetValidationIssuesAsync(daysBack, unresolvedOnly, checkCode);
    public Task<DataQualityDashboardDto> GetDataQualityDashboardAsync()
        => _repository.GetDataQualityDashboardAsync();
    public Task<ValidationIssueDto?> ResolveValidationIssueAsync(long validationId, string resolvedBy)
        => _repository.ResolveValidationIssueAsync(validationId, resolvedBy);
    public Task<byte[]> ExportMigrationHistoryExcelAsync(int topN = 100) => _repository.ExportMigrationHistoryExcelAsync(topN);
    public Task<byte[]> ExportValidationSummaryExcelAsync(int daysBack = 30) => _repository.ExportValidationSummaryExcelAsync(daysBack);
    public Task<byte[]> ExportValidationIssuesExcelAsync(int daysBack = 30) => _repository.ExportValidationIssuesExcelAsync(daysBack);
    public Task<byte[]> ExportDataQualityExcelAsync() => _repository.ExportDataQualityExcelAsync();
    public Task<byte[]> ExportMetadataUsageExcelAsync() => _repository.ExportMetadataUsageExcelAsync();
    public Task<string> ExportMigrationHistoryCsvAsync(int topN = 100) => _repository.ExportMigrationHistoryCsvAsync(topN);
    public Task<string> ExportValidationSummaryCsvAsync(int daysBack = 30) => _repository.ExportValidationSummaryCsvAsync(daysBack);
    public Task<string> ExportValidationIssuesCsvAsync(int daysBack = 30) => _repository.ExportValidationIssuesCsvAsync(daysBack);
    public Task<string> ExportDataQualityCsvAsync() => _repository.ExportDataQualityCsvAsync();
    public Task<string> ExportMetadataUsageCsvAsync() => _repository.ExportMetadataUsageCsvAsync();
}
