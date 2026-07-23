namespace EmployeeLeaveManagment.DTOs;

public class CapacityGrowthTrendDto
{
    public DateTime MetricDate { get; set; }
    public decimal? TotalSizeMB { get; set; }
    public decimal? UsedSpaceMB { get; set; }
    public decimal? UsedPercent { get; set; }
}

public class TableSizeDto
{
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public long RowCounts { get; set; }
    public decimal TotalSpaceMB { get; set; }
    public decimal UsedSpaceMB { get; set; }
    public decimal DataSpaceMB { get; set; }
    public decimal UnusedSpaceMB { get; set; }
}

public class CapStorageFileDto
{
    public string LogicalFileName { get; set; } = string.Empty;
    public string PhysicalPath { get; set; } = string.Empty;
    public string FileType { get; set; } = string.Empty;
    public string? FilegroupName { get; set; }
    public decimal SizeMB { get; set; }
    public decimal UsedMB { get; set; }
    public decimal FreeMB { get; set; }
    public decimal UsedPercent { get; set; }
    public string Autogrowth { get; set; } = string.Empty;
}

public class FilegroupUtilizationDto
{
    public string FilegroupName { get; set; } = string.Empty;
    public int FileCount { get; set; }
    public decimal SizeMB { get; set; }
    public decimal UsedMB { get; set; }
    public decimal FreeMB { get; set; }
    public decimal UsedPercent { get; set; }
}

public class CapacityForecastDto
{
    public int? ForecastId { get; set; }
    public string DatabaseName { get; set; } = string.Empty;
    public decimal CurrentSizeMB { get; set; }
    public decimal UsedSpaceMB { get; set; }
    public decimal? AvgDailyGrowthMB { get; set; }
    public decimal? ProjectedSize30dMB { get; set; }
    public decimal? ProjectedSize90dMB { get; set; }
    public int? DaysUntilFull { get; set; }
    public string ForecastMethod { get; set; } = string.Empty;
    public DateTime? CapturedAt { get; set; }
}

public class CapacityPlanningSummaryDto
{
    public string DatabaseName { get; set; } = string.Empty;
    public decimal CurrentSizeMB { get; set; }
    public decimal UsedSpaceMB { get; set; }
    public decimal UsedPercent { get; set; }
    public decimal? AvgDailyGrowthMB { get; set; }
    public decimal? ProjectedSize30dMB { get; set; }
    public decimal? ProjectedSize90dMB { get; set; }
    public int? DaysUntilFull { get; set; }
    public string ForecastMethod { get; set; } = string.Empty;
    public DateTime? ForecastCapturedAt { get; set; }
    public int OpenCapacityAlerts { get; set; }
    public DateTime CapturedAtUtc { get; set; }
}

public class SlowQueryStatDto
{
    public long ExecutionCount { get; set; }
    public long TotalElapsedMs { get; set; }
    public long? AvgElapsedMs { get; set; }
    public long TotalCpuMs { get; set; }
    public long TotalLogicalReads { get; set; }
    public long? AvgLogicalReads { get; set; }
    public DateTime? LastExecutionTime { get; set; }
    public string? ObjectName { get; set; }
    public string? QueryText { get; set; }
}

public class QueryExecutionTrendDto
{
    public DateTime ExecutionHour { get; set; }
    public int DistinctPlans { get; set; }
    public long TotalExecutions { get; set; }
    public long TotalElapsedMs { get; set; }
    public long? AvgElapsedMs { get; set; }
    public long TotalLogicalReads { get; set; }
}

public class IndexUtilizationDto
{
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public string IndexName { get; set; } = string.Empty;
    public string IndexType { get; set; } = string.Empty;
    public long UserSeeks { get; set; }
    public long UserScans { get; set; }
    public long UserLookups { get; set; }
    public long UserUpdates { get; set; }
    public DateTime? LastUserSeek { get; set; }
    public DateTime? LastUserScan { get; set; }
    public string UsageStatus { get; set; } = string.Empty;
}

public class ActiveSessionDto
{
    public int SessionId { get; set; }
    public string? LoginName { get; set; }
    public string? HostName { get; set; }
    public string? ProgramName { get; set; }
    public string? SessionStatus { get; set; }
    public string? RequestStatus { get; set; }
    public string? Command { get; set; }
    public string? WaitType { get; set; }
    public int? WaitTimeMs { get; set; }
    public int? CpuTimeMs { get; set; }
    public int? ElapsedTimeMs { get; set; }
    public int? BlockingSessionId { get; set; }
    public string? DatabaseName { get; set; }
    public string? QueryText { get; set; }
}

public class WaitStatisticDto
{
    public string WaitType { get; set; } = string.Empty;
    public long WaitingTasksCount { get; set; }
    public long WaitTimeMs { get; set; }
    public long MaxWaitTimeMs { get; set; }
    public long SignalWaitTimeMs { get; set; }
    public long ResourceWaitTimeMs { get; set; }
    public decimal WaitPercent { get; set; }
}

public class ResourceConsumptionDto
{
    public string DatabaseName { get; set; } = string.Empty;
    public int CpuCount { get; set; }
    public decimal PhysicalMemoryMB { get; set; }
    public decimal SqlCommittedMemoryMB { get; set; }
    public decimal DatabaseSizeMB { get; set; }
    public int UserSessions { get; set; }
    public int ActiveRequests { get; set; }
    public int BlockedRequests { get; set; }
    public decimal? SignalWaitPercent { get; set; }
    public DateTime CapturedAtUtc { get; set; }
}

public class CapPerfAlertDto
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

public class CapacityAlertThresholdDto
{
    public int ThresholdId { get; set; }
    public string ThresholdCode { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public decimal WarnValue { get; set; }
    public decimal CritValue { get; set; }
    public string Unit { get; set; } = string.Empty;
    public bool IsActive { get; set; }
    public DateTime ModifiedAt { get; set; }
}

public class UpdateThresholdRequestDto
{
    public decimal WarnValue { get; set; }
    public decimal CritValue { get; set; }
}

public class CapPerfFilterDto
{
    public int DaysBack { get; set; } = 30;
    public int HoursBack { get; set; } = 24;
    public int TopN { get; set; } = 25;
    public bool UnacknowledgedOnly { get; set; }
    public string? AlertType { get; set; }
    public bool IncludeUnusedOnly { get; set; }
}

public class CapPerfDashboardDto
{
    public CapacityPlanningSummaryDto Capacity { get; set; } = new();
    public ResourceConsumptionDto Resources { get; set; } = new();
    public IEnumerable<WaitStatisticDto> TopWaits { get; set; } = Array.Empty<WaitStatisticDto>();
    public IEnumerable<AlertTypeCountDto> OpenAlertsByType { get; set; } = Array.Empty<AlertTypeCountDto>();
}

public class AlertTypeCountDto
{
    public string AlertType { get; set; } = string.Empty;
    public string Severity { get; set; } = string.Empty;
    public int AlertCount { get; set; }
}
