namespace EmployeeLeaveManagment.DTOs;

public class SchemaMigrationDto
{
    public int MigrationId { get; set; }
    public string VersionNumber { get; set; } = string.Empty;
    public string MigrationName { get; set; } = string.Empty;
    public string? ScriptName { get; set; }
    public string Status { get; set; } = string.Empty;
    public DateTime AppliedAt { get; set; }
    public string AppliedBy { get; set; } = string.Empty;
    public int? DurationMs { get; set; }
    public string? ErrorMessage { get; set; }
    public string? Notes { get; set; }
}

public class ApplyMigrationRequestDto
{
    public string VersionNumber { get; set; } = string.Empty;
    public string MigrationName { get; set; } = string.Empty;
    public string? ScriptName { get; set; }
    public string UpSql { get; set; } = string.Empty;
    public string? DownSql { get; set; }
    public string? Notes { get; set; }
}

public class MetaModuleDto
{
    public int ModuleId { get; set; }
    public string ModuleCode { get; set; } = string.Empty;
    public string ModuleName { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsActive { get; set; }
    public int SortOrder { get; set; }
}

public class MetaConfigCategoryDto
{
    public int CategoryId { get; set; }
    public string CategoryCode { get; set; } = string.Empty;
    public string CategoryName { get; set; } = string.Empty;
    public string? ModuleCode { get; set; }
    public string? Description { get; set; }
    public bool IsActive { get; set; }
}

public class MetaLookupValueDto
{
    public int LookupId { get; set; }
    public string CategoryCode { get; set; } = string.Empty;
    public string LookupCode { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int SortOrder { get; set; }
    public bool IsActive { get; set; }
}

public class MetaAuditCategoryDto
{
    public int AuditCategoryId { get; set; }
    public string CategoryCode { get; set; } = string.Empty;
    public string CategoryName { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string SeverityDefault { get; set; } = string.Empty;
    public bool IsActive { get; set; }
}

public class UpsertLookupRequestDto
{
    public string CategoryCode { get; set; } = string.Empty;
    public string LookupCode { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int SortOrder { get; set; }
    public bool IsActive { get; set; } = true;
}

public class ValidationIssueDto
{
    public long ValidationId { get; set; }
    public int? RunId { get; set; }
    public string CheckCode { get; set; } = string.Empty;
    public string Severity { get; set; } = string.Empty;
    public string EntityName { get; set; } = string.Empty;
    public string? EntityKey { get; set; }
    public string ValidationDetail { get; set; } = string.Empty;
    public DateTime DetectedAt { get; set; }
    public bool IsResolved { get; set; }
    public DateTime? ResolvedAt { get; set; }
    public string? ResolvedBy { get; set; }
}

public class ValidationSummaryDto
{
    public string CheckCode { get; set; } = string.Empty;
    public string Severity { get; set; } = string.Empty;
    public int IssueCount { get; set; }
    public int OpenCount { get; set; }
    public DateTime? FirstDetectedAt { get; set; }
    public DateTime? LastDetectedAt { get; set; }
}

public class ValidationRunResultDto
{
    public int RunId { get; set; }
    public int ChecksRun { get; set; }
    public int IssuesFound { get; set; }
    public string Status { get; set; } = string.Empty;
}

public class DataQualityDashboardDto
{
    public string DataQualityStatus { get; set; } = string.Empty;
    public int OpenCritical { get; set; }
    public int OpenHigh { get; set; }
    public int OpenMedium { get; set; }
    public int OpenLow { get; set; }
    public int AppliedMigrations { get; set; }
    public int FailedMigrations { get; set; }
    public string? LastValidationStatus { get; set; }
    public DateTime? LastValidationAt { get; set; }
    public int ActiveLookups { get; set; }
    public int ActiveModules { get; set; }
    public DateTime CapturedAtUtc { get; set; }
}

public class MetadataUsageItemDto
{
    public string MetaType { get; set; } = string.Empty;
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class LookupCategoryCountDto
{
    public string CategoryCode { get; set; } = string.Empty;
    public int LookupCount { get; set; }
    public int ActiveCount { get; set; }
}

public class MetadataUsageReportDto
{
    public IEnumerable<MetadataUsageItemDto> Items { get; set; } = Array.Empty<MetadataUsageItemDto>();
    public IEnumerable<LookupCategoryCountDto> LookupCounts { get; set; } = Array.Empty<LookupCategoryCountDto>();
}

public class ResolveValidationRequestDto
{
    public string ResolvedBy { get; set; } = string.Empty;
}

public class MigrationFrameworkFilterDto
{
    public int DaysBack { get; set; } = 30;
    public int TopN { get; set; } = 100;
    public bool UnresolvedOnly { get; set; }
    public string? Status { get; set; }
    public string? CheckCode { get; set; }
}
