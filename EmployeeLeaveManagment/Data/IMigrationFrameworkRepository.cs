using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Data;

public interface IMigrationFrameworkRepository
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
