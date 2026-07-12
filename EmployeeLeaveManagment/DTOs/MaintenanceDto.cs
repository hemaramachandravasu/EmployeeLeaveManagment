namespace EmployeeLeaveManagment.DTOs;

public class DatabaseSizeDto
{
    public string DatabaseName { get; set; } = string.Empty;
    public decimal TotalSizeMB { get; set; }
    public decimal DataSizeMB { get; set; }
    public decimal LogSizeMB { get; set; }
    public decimal UsedSpaceMB { get; set; }
    public decimal FreeSpaceMB { get; set; }
    public decimal UsedPercent { get; set; }
}

public class ConnectionSummaryDto
{
    public int TotalSessions { get; set; }
    public int RunningSessions { get; set; }
    public int SessionsOnThisDb { get; set; }
}

public class FragmentationSummaryDto
{
    public decimal? AvgFragmentationPercent { get; set; }
    public decimal? MaxFragmentationPercent { get; set; }
    public int IndexesNeedingRebuild { get; set; }
    public int IndexesNeedingReorganize { get; set; }
}

public class ArchiveEntityStatDto
{
    public string EntityName { get; set; } = string.Empty;
    public int LiveRows { get; set; }
    public int ArchivedRows { get; set; }
    public decimal? ArchivedPercent { get; set; }
}

public class MaintenanceHistoryDto
{
    public int MaintenanceRunId { get; set; }
    public string JobName { get; set; } = string.Empty;
    public string StepName { get; set; } = string.Empty;
    public DateTime StartTime { get; set; }
    public DateTime? EndTime { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? Details { get; set; }
    public string? ErrorMessage { get; set; }
}

public class ArchiveHistoryDto
{
    public int ArchiveRunId { get; set; }
    public Guid ArchiveBatchId { get; set; }
    public string EntityName { get; set; } = string.Empty;
    public DateTime StartTime { get; set; }
    public DateTime? EndTime { get; set; }
    public string Status { get; set; } = string.Empty;
    public int? RowsArchived { get; set; }
    public int? RetentionDays { get; set; }
}

public class DatabaseHealthDashboardDto
{
    public DatabaseSizeDto DatabaseSize { get; set; } = new();
    public ConnectionSummaryDto Connections { get; set; } = new();
    public FragmentationSummaryDto Fragmentation { get; set; } = new();
    public IEnumerable<ArchiveEntityStatDto> ArchiveStatistics { get; set; } = Array.Empty<ArchiveEntityStatDto>();
    public IEnumerable<MaintenanceHistoryDto> MaintenanceHistory { get; set; } = Array.Empty<MaintenanceHistoryDto>();
    public IEnumerable<ArchiveHistoryDto> ArchiveHistory { get; set; } = Array.Empty<ArchiveHistoryDto>();
}

public class MonthlyGrowthDto
{
    public int Year { get; set; }
    public int Month { get; set; }
    public string MonthName { get; set; } = string.Empty;
    public decimal? TotalSizeMB { get; set; }
    public decimal? UsedSpaceMB { get; set; }
    public decimal? UsedPercent { get; set; }
}

public class IndexHealthDto
{
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public string IndexName { get; set; } = string.Empty;
    public string IndexType { get; set; } = string.Empty;
    public decimal FragmentationPercent { get; set; }
    public long PageCount { get; set; }
    public string HealthStatus { get; set; } = string.Empty;
}

public class QueryPerformanceDto
{
    public long ExecutionCount { get; set; }
    public long TotalElapsedMs { get; set; }
    public long? AvgElapsedMs { get; set; }
    public long TotalCpuMs { get; set; }
    public long TotalLogicalReads { get; set; }
    public DateTime? LastExecutionTime { get; set; }
    public string QueryText { get; set; } = string.Empty;
}

public class ArchiveSummaryDto
{
    public string EntityName { get; set; } = string.Empty;
    public int RunCount { get; set; }
    public int SuccessCount { get; set; }
    public int FailedCount { get; set; }
    public int TotalRowsArchived { get; set; }
    public DateTime? FirstRun { get; set; }
    public DateTime? LastRun { get; set; }
}

public class MaintenanceExecutionSummaryDto
{
    public string JobName { get; set; } = string.Empty;
    public string StepName { get; set; } = string.Empty;
    public int RunCount { get; set; }
    public int SuccessCount { get; set; }
    public int FailedCount { get; set; }
    public DateTime? FirstRun { get; set; }
    public DateTime? LastRun { get; set; }
    public int? AvgDurationSeconds { get; set; }
}

public class RetentionConfigDto
{
    public int ConfigId { get; set; }
    public string EntityName { get; set; } = string.Empty;
    public int RetentionDays { get; set; }
    public bool IsEnabled { get; set; }
    public string? Description { get; set; }
    public DateTime LastModifiedUtc { get; set; }
}

public class UpdateRetentionRequestDto
{
    public string EntityName { get; set; } = string.Empty;
    public int RetentionDays { get; set; }
    public bool IsEnabled { get; set; } = true;
}

public class MaintenanceFilterDto
{
    public int? MonthsBack { get; set; }
    public int? DaysBack { get; set; }
    public int? TopN { get; set; }
    public int? MinPageCount { get; set; }
}
