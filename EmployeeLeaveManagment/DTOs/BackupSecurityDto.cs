namespace EmployeeLeaveManagment.DTOs;

public class BackupHistoryDto
{
    public int BackupRunId { get; set; }
    public string DatabaseName { get; set; } = string.Empty;
    public string BackupType { get; set; } = string.Empty;
    public string BackupPath { get; set; } = string.Empty;
    public DateTime StartTime { get; set; }
    public DateTime? EndTime { get; set; }
    public string Status { get; set; } = string.Empty;
    public decimal? BackupSizeMB { get; set; }
    public bool Verified { get; set; }
    public int? DurationSeconds { get; set; }
    public string? ErrorMessage { get; set; }
}

public class RecoveryValidationDto
{
    public int ValidationId { get; set; }
    public string DatabaseName { get; set; } = string.Empty;
    public string ValidationType { get; set; } = string.Empty;
    public string? BackupPath { get; set; }
    public DateTime? TargetPointInTime { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime? EndTime { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? Details { get; set; }
    public string? ErrorMessage { get; set; }
}

public class SecurityAccessSummaryDto
{
    public string? LoginName { get; set; }
    public int SessionSightings { get; set; }
    public int DistinctHosts { get; set; }
    public int DistinctPrograms { get; set; }
    public DateTime? FirstSeen { get; set; }
    public DateTime? LastSeen { get; set; }
}

public class SecurityRoleMemberCountDto
{
    public string RoleName { get; set; } = string.Empty;
    public int MemberCount { get; set; }
}

public class MaskedColumnDto
{
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public string ColumnName { get; set; } = string.Empty;
    public bool IsMasked { get; set; }
}

public class SecurityAuditSummaryDto
{
    public IEnumerable<SecurityAccessSummaryDto> AccessByLogin { get; set; } = Array.Empty<SecurityAccessSummaryDto>();
    public IEnumerable<SecurityRoleMemberCountDto> RoleMembers { get; set; } = Array.Empty<SecurityRoleMemberCountDto>();
    public IEnumerable<MaskedColumnDto> MaskedColumns { get; set; } = Array.Empty<MaskedColumnDto>();
}

public class DatabaseHealthStatusDto
{
    public string DatabaseName { get; set; } = string.Empty;
    public string RecoveryModel { get; set; } = string.Empty;
    public string StateDesc { get; set; } = string.Empty;
    public decimal TotalSizeMB { get; set; }
    public int ActiveUserSessions { get; set; }
    public int FailedBackupsLast24h { get; set; }
    public int OpenCriticalAlerts { get; set; }
    public DateTime CapturedAtUtc { get; set; }
}

public class JobExecutionHistoryDto
{
    public string JobName { get; set; } = string.Empty;
    public int StepId { get; set; }
    public string StepName { get; set; } = string.Empty;
    public DateTime RunDateTime { get; set; }
    public string StatusName { get; set; } = string.Empty;
    public int RunDuration { get; set; }
    public string? MessageText { get; set; }
}

public class BackupStatusDto
{
    public string DatabaseName { get; set; } = string.Empty;
    public string RecoveryModel { get; set; } = string.Empty;
    public DateTime? LastFullBackupUtc { get; set; }
    public string? LastFullStatus { get; set; }
    public DateTime? LastDiffBackupUtc { get; set; }
    public DateTime? LastLogBackupUtc { get; set; }
    public string? LastLogStatus { get; set; }
    public int? FullBackupAgeHours { get; set; }
    public int? LogBackupAgeMinutes { get; set; }
    public string FullBackupHealth { get; set; } = string.Empty;
    public string LogBackupHealth { get; set; } = string.Empty;
    public int FailedBackupsLast7Days { get; set; }
}

public class OpsAlertDto
{
    public int AlertId { get; set; }
    public string AlertType { get; set; } = string.Empty;
    public string Severity { get; set; } = string.Empty;
    public string MessageText { get; set; } = string.Empty;
    public decimal? MetricValue { get; set; }
    public decimal? ThresholdValue { get; set; }
    public DateTime CapturedAt { get; set; }
    public bool IsAcknowledged { get; set; }
}

public class PitRestoreScriptDto
{
    public string RestoreScript { get; set; } = string.Empty;
    public string? FullBackupPath { get; set; }
    public string? DifferentialBackupPath { get; set; }
    public DateTime PointInTimeUtc { get; set; }
    public string TargetDatabase { get; set; } = string.Empty;
}

public class BackupSecurityFilterDto
{
    public int? DaysBack { get; set; }
    public int? HoursBack { get; set; }
    public string? DatabaseName { get; set; }
    public DateTime? PointInTimeUtc { get; set; }
}
