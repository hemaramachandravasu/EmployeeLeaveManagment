using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Services;

public class BackupSecurityService : IBackupSecurityService
{
    private readonly IBackupSecurityRepository _repository;

    public BackupSecurityService(IBackupSecurityRepository repository)
    {
        _repository = repository;
    }

    public Task<BackupStatusDto> GetBackupStatusAsync(string databaseName = "EmployeeLeaveDb")
        => _repository.GetBackupStatusAsync(databaseName);

    public Task<IEnumerable<BackupHistoryDto>> GetBackupHistoryAsync(int daysBack = 30, string databaseName = "EmployeeLeaveDb")
        => _repository.GetBackupHistoryAsync(daysBack, databaseName);

    public Task<IEnumerable<RecoveryValidationDto>> GetRecoveryValidationAsync(int daysBack = 30)
        => _repository.GetRecoveryValidationAsync(daysBack);

    public Task<SecurityAuditSummaryDto> GetSecurityAuditSummaryAsync(int hoursBack = 24)
        => _repository.GetSecurityAuditSummaryAsync(hoursBack);

    public Task<DatabaseHealthStatusDto> GetDatabaseHealthStatusAsync()
        => _repository.GetDatabaseHealthStatusAsync();

    public Task<IEnumerable<JobExecutionHistoryDto>> GetJobExecutionHistoryAsync(int hoursBack = 72)
        => _repository.GetJobExecutionHistoryAsync(hoursBack);

    public Task<IEnumerable<OpsAlertDto>> GetOpsAlertsAsync(int daysBack = 7, bool unacknowledgedOnly = false)
        => _repository.GetOpsAlertsAsync(daysBack, unacknowledgedOnly);

    public Task<PitRestoreScriptDto> GeneratePointInTimeRestoreScriptAsync(DateTime pointInTimeUtc, string? targetDatabase = null)
        => _repository.GeneratePointInTimeRestoreScriptAsync(pointInTimeUtc, targetDatabase);

    public Task<byte[]> ExportBackupHistoryExcelAsync(int daysBack = 30)
        => _repository.ExportBackupHistoryExcelAsync(daysBack);

    public Task<byte[]> ExportRecoveryValidationExcelAsync(int daysBack = 30)
        => _repository.ExportRecoveryValidationExcelAsync(daysBack);

    public Task<byte[]> ExportSecurityAuditExcelAsync(int hoursBack = 24)
        => _repository.ExportSecurityAuditExcelAsync(hoursBack);

    public Task<byte[]> ExportDatabaseHealthExcelAsync()
        => _repository.ExportDatabaseHealthExcelAsync();

    public Task<byte[]> ExportJobExecutionExcelAsync(int hoursBack = 72)
        => _repository.ExportJobExecutionExcelAsync(hoursBack);

    public Task<string> ExportBackupHistoryCsvAsync(int daysBack = 30)
        => _repository.ExportBackupHistoryCsvAsync(daysBack);

    public Task<string> ExportRecoveryValidationCsvAsync(int daysBack = 30)
        => _repository.ExportRecoveryValidationCsvAsync(daysBack);

    public Task<string> ExportSecurityAuditCsvAsync(int hoursBack = 24)
        => _repository.ExportSecurityAuditCsvAsync(hoursBack);

    public Task<string> ExportDatabaseHealthCsvAsync()
        => _repository.ExportDatabaseHealthCsvAsync();

    public Task<string> ExportJobExecutionCsvAsync(int hoursBack = 72)
        => _repository.ExportJobExecutionCsvAsync(hoursBack);
}
