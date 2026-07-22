using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Services;

public class AuditIntegrityService : IAuditIntegrityService
{
    private readonly IAuditIntegrityRepository _repository;

    public AuditIntegrityService(IAuditIntegrityRepository repository)
    {
        _repository = repository;
    }

    public Task<IntegrityCheckResultDto> RunAllIntegrityChecksAsync(int? balanceYear = null)
        => _repository.RunAllIntegrityChecksAsync(balanceYear);

    public Task<IEnumerable<IntegrityViolationDto>> GetIntegrityViolationsAsync(int daysBack = 30, bool unresolvedOnly = false, string? severity = null)
        => _repository.GetIntegrityViolationsAsync(daysBack, unresolvedOnly, severity);

    public Task<IEnumerable<AuditSummaryDto>> GetAuditSummaryAsync(int daysBack = 30)
        => _repository.GetAuditSummaryAsync(daysBack);

    public Task<DataQualityStatusDto> GetDataQualityStatusAsync()
        => _repository.GetDataQualityStatusAsync();

    public Task<IEnumerable<UserActivitySummaryDto>> GetUserActivitySummaryAsync(int daysBack = 30)
        => _repository.GetUserActivitySummaryAsync(daysBack);

    public Task<ComplianceStatusDto> GetComplianceStatusAsync()
        => _repository.GetComplianceStatusAsync();

    public Task<IEnumerable<ComplianceRunDto>> GetFailedValidationChecksAsync(int hoursBack = 48)
        => _repository.GetFailedValidationChecksAsync(hoursBack);

    public Task<IEnumerable<DatabaseExceptionDto>> GetDatabaseExceptionsAsync(int hoursBack = 48)
        => _repository.GetDatabaseExceptionsAsync(hoursBack);

    public Task<IEnumerable<ComplianceRunDto>> GetScheduledAuditJobHistoryAsync(int hoursBack = 72)
        => _repository.GetScheduledAuditJobHistoryAsync(hoursBack);

    public Task<IntegrityViolationDto?> ResolveViolationAsync(long violationId, ResolveViolationRequestDto request)
        => _repository.ResolveViolationAsync(violationId, request);

    public Task<long> LogUserActivityAsync(LogUserActivityRequestDto request)
        => _repository.LogUserActivityAsync(request);

    public Task<byte[]> ExportIntegrityViolationsExcelAsync(int daysBack = 30, bool unresolvedOnly = false)
        => _repository.ExportIntegrityViolationsExcelAsync(daysBack, unresolvedOnly);

    public Task<byte[]> ExportAuditSummaryExcelAsync(int daysBack = 30)
        => _repository.ExportAuditSummaryExcelAsync(daysBack);

    public Task<byte[]> ExportDataQualityExcelAsync()
        => _repository.ExportDataQualityExcelAsync();

    public Task<byte[]> ExportUserActivityExcelAsync(int daysBack = 30)
        => _repository.ExportUserActivityExcelAsync(daysBack);

    public Task<byte[]> ExportComplianceStatusExcelAsync()
        => _repository.ExportComplianceStatusExcelAsync();

    public Task<string> ExportIntegrityViolationsCsvAsync(int daysBack = 30, bool unresolvedOnly = false)
        => _repository.ExportIntegrityViolationsCsvAsync(daysBack, unresolvedOnly);

    public Task<string> ExportAuditSummaryCsvAsync(int daysBack = 30)
        => _repository.ExportAuditSummaryCsvAsync(daysBack);

    public Task<string> ExportDataQualityCsvAsync()
        => _repository.ExportDataQualityCsvAsync();

    public Task<string> ExportUserActivityCsvAsync(int daysBack = 30)
        => _repository.ExportUserActivityCsvAsync(daysBack);

    public Task<string> ExportComplianceStatusCsvAsync()
        => _repository.ExportComplianceStatusCsvAsync();
}
