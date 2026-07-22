namespace EmployeeLeaveManagment.DTOs;

public class PerformanceSummaryDto
{
    public string DatabaseName { get; set; } = string.Empty;
    public decimal TotalSizeMB { get; set; }
    public decimal DataSizeMB { get; set; }
    public decimal LogSizeMB { get; set; }
    public decimal UsedSpaceMB { get; set; }
    public decimal UsedPercent { get; set; }
    public int ActiveUserSessions { get; set; }
    public int SuspendedRequests { get; set; }
    public int BlockedRequests { get; set; }
    public int PartitionedTables { get; set; }
    public int FailedOptJobsLast7Days { get; set; }
    public DateTime CapturedAtUtc { get; set; }
}

public class QueryExecutionStatDto
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

public class TableGrowthDto
{
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public long RowCounts { get; set; }
    public decimal TotalSpaceMB { get; set; }
    public decimal UsedSpaceMB { get; set; }
    public decimal DataSpaceMB { get; set; }
    public bool IsPartitioned { get; set; }
    public string PartitionSchemeOrFilegroup { get; set; } = string.Empty;
    public int PartitionCount { get; set; }
}

public class StorageUtilizationDto
{
    public string? FilegroupName { get; set; }
    public string LogicalFileName { get; set; } = string.Empty;
    public string PhysicalPath { get; set; } = string.Empty;
    public string FileType { get; set; } = string.Empty;
    public decimal SizeMB { get; set; }
    public decimal UsedMB { get; set; }
    public decimal FreeMB { get; set; }
    public decimal UsedPercent { get; set; }
    public int GrowthSetting { get; set; }
    public string GrowthUnit { get; set; } = string.Empty;
}

public class OptIndexHealthDto
{
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public string IndexName { get; set; } = string.Empty;
    public int PartitionNumber { get; set; }
    public string IndexType { get; set; } = string.Empty;
    public decimal FragmentationPercent { get; set; }
    public long PageCount { get; set; }
    public double? AvgPageSpaceUsedPercent { get; set; }
    public string RecommendedAction { get; set; } = string.Empty;
    public bool IsPartitionAligned { get; set; }
    public string? PartitionScheme { get; set; }
}

public class PartitionInfoDto
{
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public string? IndexName { get; set; }
    public int PartitionNumber { get; set; }
    public string FilegroupName { get; set; } = string.Empty;
    public long RowCounts { get; set; }
    public object? LowerBoundaryInclusive { get; set; }
    public object? UpperBoundaryExclusive { get; set; }
    public string PartitionFunction { get; set; } = string.Empty;
    public string PartitionScheme { get; set; } = string.Empty;
    public decimal? TotalSpaceMB { get; set; }
}

public class OptHealthCheckDto
{
    public string DatabaseName { get; set; } = string.Empty;
    public string HealthStatus { get; set; } = string.Empty;
    public string Details { get; set; } = string.Empty;
    public DateTime CapturedAtUtc { get; set; }
}

public class OptimizationFilterDto
{
    public int TopN { get; set; } = 25;
    public int MinPageCount { get; set; } = 50;
    public string? TableName { get; set; }
}
