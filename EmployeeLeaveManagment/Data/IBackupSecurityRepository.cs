using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Data;

public interface IBackupSecurityRepository
{
    Task<BackupStatusDto> GetBackupStatusAsync(string databaseName = "EmployeeLeaveDb");
    Task<IEnumerable<BackupHistoryDto>> GetBackupHistoryAsync(int daysBack = 30, string databaseName = "EmployeeLeaveDb");
    Task<IEnumerable<RecoveryValidationDto>> GetRecoveryValidationAsync(int daysBack = 30);
    Task<SecurityAuditSummaryDto> GetSecurityAuditSummaryAsync(int hoursBack = 24);
    Task<DatabaseHealthStatusDto> GetDatabaseHealthStatusAsync();
    Task<IEnumerable<JobExecutionHistoryDto>> GetJobExecutionHistoryAsync(int hoursBack = 72);
    Task<IEnumerable<OpsAlertDto>> GetOpsAlertsAsync(int daysBack = 7, bool unacknowledgedOnly = false);
    Task<PitRestoreScriptDto> GeneratePointInTimeRestoreScriptAsync(DateTime pointInTimeUtc, string? targetDatabase = null);
    Task<byte[]> ExportBackupHistoryExcelAsync(int daysBack = 30);
    Task<byte[]> ExportRecoveryValidationExcelAsync(int daysBack = 30);
    Task<byte[]> ExportSecurityAuditExcelAsync(int hoursBack = 24);
    Task<byte[]> ExportDatabaseHealthExcelAsync();
    Task<byte[]> ExportJobExecutionExcelAsync(int hoursBack = 72);
    Task<string> ExportBackupHistoryCsvAsync(int daysBack = 30);
    Task<string> ExportRecoveryValidationCsvAsync(int daysBack = 30);
    Task<string> ExportSecurityAuditCsvAsync(int hoursBack = 24);
    Task<string> ExportDatabaseHealthCsvAsync();
    Task<string> ExportJobExecutionCsvAsync(int hoursBack = 72);
}
