using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Data;

public interface IAuditIntegrityRepository
{
    Task<IntegrityCheckResultDto> RunAllIntegrityChecksAsync(int? balanceYear = null);
    Task<IEnumerable<IntegrityViolationDto>> GetIntegrityViolationsAsync(int daysBack = 30, bool unresolvedOnly = false, string? severity = null);
    Task<IEnumerable<AuditSummaryDto>> GetAuditSummaryAsync(int daysBack = 30);
    Task<DataQualityStatusDto> GetDataQualityStatusAsync();
    Task<IEnumerable<UserActivitySummaryDto>> GetUserActivitySummaryAsync(int daysBack = 30);
    Task<ComplianceStatusDto> GetComplianceStatusAsync();
    Task<IEnumerable<ComplianceRunDto>> GetFailedValidationChecksAsync(int hoursBack = 48);
    Task<IEnumerable<DatabaseExceptionDto>> GetDatabaseExceptionsAsync(int hoursBack = 48);
    Task<IEnumerable<ComplianceRunDto>> GetScheduledAuditJobHistoryAsync(int hoursBack = 72);
    Task<IntegrityViolationDto?> ResolveViolationAsync(long violationId, ResolveViolationRequestDto request);
    Task<long> LogUserActivityAsync(LogUserActivityRequestDto request);

    Task<byte[]> ExportIntegrityViolationsExcelAsync(int daysBack = 30, bool unresolvedOnly = false);
    Task<byte[]> ExportAuditSummaryExcelAsync(int daysBack = 30);
    Task<byte[]> ExportDataQualityExcelAsync();
    Task<byte[]> ExportUserActivityExcelAsync(int daysBack = 30);
    Task<byte[]> ExportComplianceStatusExcelAsync();

    Task<string> ExportIntegrityViolationsCsvAsync(int daysBack = 30, bool unresolvedOnly = false);
    Task<string> ExportAuditSummaryCsvAsync(int daysBack = 30);
    Task<string> ExportDataQualityCsvAsync();
    Task<string> ExportUserActivityCsvAsync(int daysBack = 30);
    Task<string> ExportComplianceStatusCsvAsync();
}
