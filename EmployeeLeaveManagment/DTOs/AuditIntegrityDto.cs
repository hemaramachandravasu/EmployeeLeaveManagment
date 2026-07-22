namespace EmployeeLeaveManagment.DTOs;

public class IntegrityViolationDto
{
    public long ViolationId { get; set; }
    public int? RunId { get; set; }
    public string CheckCode { get; set; } = string.Empty;
    public string Severity { get; set; } = string.Empty;
    public string EntityName { get; set; } = string.Empty;
    public int? EntityId { get; set; }
    public int? EmployeeId { get; set; }
    public string ViolationDetail { get; set; } = string.Empty;
    public DateTime DetectedAt { get; set; }
    public bool IsResolved { get; set; }
    public DateTime? ResolvedAt { get; set; }
    public string? ResolvedBy { get; set; }
    public string? ResolutionNotes { get; set; }
}

public class AuditSummaryDto
{
    public string TableName { get; set; } = string.Empty;
    public string ActionType { get; set; } = string.Empty;
    public int EventCount { get; set; }
    public int DistinctActors { get; set; }
    public DateTime? FirstEventAt { get; set; }
    public DateTime? LastEventAt { get; set; }
}

public class DataQualityStatusDto
{
    public string DataQualityStatus { get; set; } = string.Empty;
    public int OpenCritical { get; set; }
    public int OpenHigh { get; set; }
    public int OpenMedium { get; set; }
    public int OpenLow { get; set; }
    public int AuditEventsLast7Days { get; set; }
    public int UserActivityLast7Days { get; set; }
    public int ExceptionsLast7Days { get; set; }
    public string? LastComplianceRunStatus { get; set; }
    public DateTime? LastComplianceRunAt { get; set; }
    public int ActiveHolidays { get; set; }
    public int ActivePolicies { get; set; }
    public DateTime CapturedAtUtc { get; set; }
}

public class UserActivitySummaryDto
{
    public string UserName { get; set; } = string.Empty;
    public string ActivityType { get; set; } = string.Empty;
    public int ActivityCount { get; set; }
    public int SuccessCount { get; set; }
    public int FailureCount { get; set; }
    public DateTime? FirstActivityAt { get; set; }
    public DateTime? LastActivityAt { get; set; }
}

public class ComplianceStatusDto
{
    public string ComplianceStatus { get; set; } = string.Empty;
    public int OpenViolations { get; set; }
    public int OpenCriticalViolations { get; set; }
    public int FailedRunsLast24h { get; set; }
    public int ExceptionsLast24h { get; set; }
    public DateTime? LastSuccessfulCheckAt { get; set; }
    public int AuditEventsLast24h { get; set; }
    public int UserActivityLast24h { get; set; }
    public DateTime CapturedAtUtc { get; set; }
}

public class ComplianceRunDto
{
    public int RunId { get; set; }
    public string JobName { get; set; } = string.Empty;
    public string StepName { get; set; } = string.Empty;
    public DateTime StartTime { get; set; }
    public DateTime? EndTime { get; set; }
    public string Status { get; set; } = string.Empty;
    public int? ChecksRun { get; set; }
    public int? ViolationsFound { get; set; }
    public string? Details { get; set; }
    public string? ErrorMessage { get; set; }
}

public class DatabaseExceptionDto
{
    public long ExceptionId { get; set; }
    public string? SourceProc { get; set; }
    public int? ErrorNumber { get; set; }
    public int? ErrorSeverity { get; set; }
    public int? ErrorState { get; set; }
    public string ErrorMessage { get; set; } = string.Empty;
    public DateTime CapturedAt { get; set; }
    public string? ContextInfo { get; set; }
}

public class IntegrityCheckResultDto
{
    public int RunId { get; set; }
    public int ChecksRun { get; set; }
    public int ViolationsFound { get; set; }
    public string Status { get; set; } = string.Empty;
}

public class LogUserActivityRequestDto
{
    public int? UserId { get; set; }
    public string? UserName { get; set; }
    public string ActivityType { get; set; } = string.Empty;
    public string? EntityName { get; set; }
    public int? EntityId { get; set; }
    public string? ActivityDetail { get; set; }
    public string? IpAddress { get; set; }
    public bool Success { get; set; } = true;
}

public class ResolveViolationRequestDto
{
    public string ResolvedBy { get; set; } = string.Empty;
    public string? ResolutionNotes { get; set; }
}

public class AuditIntegrityFilterDto
{
    public int DaysBack { get; set; } = 30;
    public int HoursBack { get; set; } = 48;
    public bool UnresolvedOnly { get; set; }
    public string? Severity { get; set; }
}
