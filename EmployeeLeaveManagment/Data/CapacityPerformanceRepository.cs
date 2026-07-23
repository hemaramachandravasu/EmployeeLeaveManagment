using ClosedXML.Excel;
using EmployeeLeaveManagment.DTOs;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Globalization;
using System.Text;

namespace EmployeeLeaveManagment.Data;

public class CapacityPerformanceRepository : ICapacityPerformanceRepository
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public CapacityPerformanceRepository(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<CapPerfDashboardDto> GetDashboardAsync()
    {
        CapPerfDashboardDto dto = new();
        List<WaitStatisticDto> waits = new();
        List<AlertTypeCountDto> alerts = new();

        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_CapPerf_Dashboard", connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 120
        };
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
            dto.Capacity = MapCapacitySummary(reader);

        if (await reader.NextResultAsync() && await reader.ReadAsync())
            dto.Resources = MapResource(reader);

        if (await reader.NextResultAsync())
        {
            while (await reader.ReadAsync())
                waits.Add(MapWait(reader));
        }

        if (await reader.NextResultAsync())
        {
            while (await reader.ReadAsync())
            {
                alerts.Add(new AlertTypeCountDto
                {
                    AlertType = reader["AlertType"].ToString()!,
                    Severity = reader["Severity"].ToString()!,
                    AlertCount = Convert.ToInt32(reader["AlertCount"])
                });
            }
        }

        dto.TopWaits = waits;
        dto.OpenAlertsByType = alerts;
        return dto;
    }

    public async Task<IEnumerable<CapacityGrowthTrendDto>> GetGrowthTrendsAsync(int daysBack = 90)
    {
        List<CapacityGrowthTrendDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Cap_DatabaseGrowthTrends", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@DaysBack", daysBack);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new CapacityGrowthTrendDto
            {
                MetricDate = Convert.ToDateTime(reader["MetricDate"]),
                TotalSizeMB = GetNullableDecimal(reader, "TotalSizeMB"),
                UsedSpaceMB = GetNullableDecimal(reader, "UsedSpaceMB"),
                UsedPercent = GetNullableDecimal(reader, "UsedPercent")
            });
        }
        return results;
    }

    public async Task<IEnumerable<TableSizeDto>> GetTableSizesAsync()
    {
        List<TableSizeDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Cap_TableSizeAnalysis", connection) { CommandType = CommandType.StoredProcedure };
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new TableSizeDto
            {
                SchemaName = reader["SchemaName"].ToString()!,
                TableName = reader["TableName"].ToString()!,
                RowCounts = Convert.ToInt64(reader["RowCounts"]),
                TotalSpaceMB = Convert.ToDecimal(reader["TotalSpaceMB"]),
                UsedSpaceMB = Convert.ToDecimal(reader["UsedSpaceMB"]),
                DataSpaceMB = Convert.ToDecimal(reader["DataSpaceMB"]),
                UnusedSpaceMB = Convert.ToDecimal(reader["UnusedSpaceMB"])
            });
        }
        return results;
    }

    public async Task<IEnumerable<CapStorageFileDto>> GetStorageUtilizationAsync()
    {
        List<CapStorageFileDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Cap_StorageUtilization", connection) { CommandType = CommandType.StoredProcedure };
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new CapStorageFileDto
            {
                LogicalFileName = reader["LogicalFileName"].ToString()!,
                PhysicalPath = reader["PhysicalPath"].ToString()!,
                FileType = reader["FileType"].ToString()!,
                FilegroupName = GetNullableString(reader, "FilegroupName"),
                SizeMB = Convert.ToDecimal(reader["SizeMB"]),
                UsedMB = Convert.ToDecimal(reader["UsedMB"]),
                FreeMB = Convert.ToDecimal(reader["FreeMB"]),
                UsedPercent = Convert.ToDecimal(reader["UsedPercent"]),
                Autogrowth = reader["Autogrowth"].ToString()!
            });
        }
        return results;
    }

    public async Task<IEnumerable<FilegroupUtilizationDto>> GetFilegroupUtilizationAsync()
    {
        List<FilegroupUtilizationDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Cap_FilegroupUtilization", connection) { CommandType = CommandType.StoredProcedure };
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new FilegroupUtilizationDto
            {
                FilegroupName = reader["FilegroupName"].ToString()!,
                FileCount = Convert.ToInt32(reader["FileCount"]),
                SizeMB = Convert.ToDecimal(reader["SizeMB"]),
                UsedMB = Convert.ToDecimal(reader["UsedMB"]),
                FreeMB = Convert.ToDecimal(reader["FreeMB"]),
                UsedPercent = Convert.ToDecimal(reader["UsedPercent"])
            });
        }
        return results;
    }

    public async Task<CapacityForecastDto> ForecastCapacityAsync(int lookbackDays = 90)
    {
        CapacityForecastDto dto = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Cap_ForecastCapacity", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@LookbackDays", lookbackDays);
        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            dto.ForecastId = GetNullableInt32(reader, "ForecastId");
            dto.DatabaseName = reader["DatabaseName"].ToString()!;
            dto.CurrentSizeMB = Convert.ToDecimal(reader["CurrentSizeMB"]);
            dto.UsedSpaceMB = Convert.ToDecimal(reader["UsedSpaceMB"]);
            dto.AvgDailyGrowthMB = GetNullableDecimal(reader, "AvgDailyGrowthMB");
            dto.ProjectedSize30dMB = GetNullableDecimal(reader, "ProjectedSize30dMB");
            dto.ProjectedSize90dMB = GetNullableDecimal(reader, "ProjectedSize90dMB");
            dto.DaysUntilFull = GetNullableInt32(reader, "DaysUntilFull");
            dto.ForecastMethod = reader["ForecastMethod"].ToString()!;
            dto.CapturedAt = GetNullableDateTime(reader, "CapturedAt");
        }
        return dto;
    }

    public async Task<CapacityPlanningSummaryDto> GetCapacityPlanningSummaryAsync()
    {
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Report_CapacityPlanningSummary", connection) { CommandType = CommandType.StoredProcedure };
        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
            return MapCapacitySummary(reader);
        return new CapacityPlanningSummaryDto();
    }

    public async Task<IEnumerable<SlowQueryStatDto>> GetSlowQueryStatisticsAsync(int topN = 25)
    {
        List<SlowQueryStatDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Perf_SlowQueryStatistics", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@TopN", topN);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new SlowQueryStatDto
            {
                ExecutionCount = Convert.ToInt64(reader["ExecutionCount"]),
                TotalElapsedMs = Convert.ToInt64(reader["TotalElapsedMs"]),
                AvgElapsedMs = GetNullableInt64(reader, "AvgElapsedMs"),
                TotalCpuMs = Convert.ToInt64(reader["TotalCpuMs"]),
                TotalLogicalReads = Convert.ToInt64(reader["TotalLogicalReads"]),
                AvgLogicalReads = GetNullableInt64(reader, "AvgLogicalReads"),
                LastExecutionTime = GetNullableDateTime(reader, "LastExecutionTime"),
                ObjectName = GetNullableString(reader, "ObjectName"),
                QueryText = GetNullableString(reader, "QueryText")
            });
        }
        return results;
    }

    public async Task<IEnumerable<QueryExecutionTrendDto>> GetQueryExecutionTrendsAsync(int hoursBack = 24)
    {
        List<QueryExecutionTrendDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Perf_QueryExecutionTrends", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@HoursBack", hoursBack);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new QueryExecutionTrendDto
            {
                ExecutionHour = Convert.ToDateTime(reader["ExecutionHour"]),
                DistinctPlans = Convert.ToInt32(reader["DistinctPlans"]),
                TotalExecutions = Convert.ToInt64(reader["TotalExecutions"]),
                TotalElapsedMs = Convert.ToInt64(reader["TotalElapsedMs"]),
                AvgElapsedMs = GetNullableInt64(reader, "AvgElapsedMs"),
                TotalLogicalReads = Convert.ToInt64(reader["TotalLogicalReads"])
            });
        }
        return results;
    }

    public async Task<IEnumerable<IndexUtilizationDto>> GetIndexUtilizationAsync(bool includeUnusedOnly = false)
    {
        List<IndexUtilizationDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Perf_IndexUtilization", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@IncludeUnusedOnly", includeUnusedOnly);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new IndexUtilizationDto
            {
                SchemaName = reader["SchemaName"].ToString()!,
                TableName = reader["TableName"].ToString()!,
                IndexName = reader["IndexName"].ToString()!,
                IndexType = reader["IndexType"].ToString()!,
                UserSeeks = Convert.ToInt64(reader["UserSeeks"]),
                UserScans = Convert.ToInt64(reader["UserScans"]),
                UserLookups = Convert.ToInt64(reader["UserLookups"]),
                UserUpdates = Convert.ToInt64(reader["UserUpdates"]),
                LastUserSeek = GetNullableDateTime(reader, "LastUserSeek"),
                LastUserScan = GetNullableDateTime(reader, "LastUserScan"),
                UsageStatus = reader["UsageStatus"].ToString()!
            });
        }
        return results;
    }

    public async Task<IEnumerable<ActiveSessionDto>> GetActiveSessionsAsync()
    {
        List<ActiveSessionDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Perf_ActiveSessions", connection) { CommandType = CommandType.StoredProcedure };
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new ActiveSessionDto
            {
                SessionId = Convert.ToInt32(reader["SessionId"]),
                LoginName = GetNullableString(reader, "LoginName"),
                HostName = GetNullableString(reader, "HostName"),
                ProgramName = GetNullableString(reader, "ProgramName"),
                SessionStatus = GetNullableString(reader, "SessionStatus"),
                RequestStatus = GetNullableString(reader, "RequestStatus"),
                Command = GetNullableString(reader, "Command"),
                WaitType = GetNullableString(reader, "WaitType"),
                WaitTimeMs = GetNullableInt32(reader, "WaitTimeMs"),
                CpuTimeMs = GetNullableInt32(reader, "CpuTimeMs"),
                ElapsedTimeMs = GetNullableInt32(reader, "ElapsedTimeMs"),
                BlockingSessionId = GetNullableInt32(reader, "BlockingSessionId"),
                DatabaseName = GetNullableString(reader, "DatabaseName"),
                QueryText = GetNullableString(reader, "QueryText")
            });
        }
        return results;
    }

    public async Task<IEnumerable<WaitStatisticDto>> GetWaitStatisticsAsync(int topN = 25)
    {
        List<WaitStatisticDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Perf_WaitStatistics", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@TopN", topN);
        command.Parameters.AddWithValue("@PersistSnapshot", false);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            results.Add(MapWait(reader));
        return results;
    }

    public async Task<ResourceConsumptionDto> GetResourceConsumptionAsync()
    {
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Perf_ResourceConsumptionSummary", connection) { CommandType = CommandType.StoredProcedure };
        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
            return MapResource(reader);
        return new ResourceConsumptionDto();
    }

    public async Task<IEnumerable<CapPerfAlertDto>> GetAlertHistoryAsync(int daysBack = 30, bool unacknowledgedOnly = false, string? alertType = null)
    {
        List<CapPerfAlertDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Report_CapPerfAlertHistory", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@DaysBack", daysBack);
        command.Parameters.AddWithValue("@UnacknowledgedOnly", unacknowledgedOnly);
        command.Parameters.AddWithValue("@AlertType", (object?)alertType ?? DBNull.Value);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            results.Add(MapAlert(reader));
        return results;
    }

    public async Task RunAllAlertsAsync()
    {
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_CapPerf_RunAllAlerts", connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 180
        };
        await command.ExecuteNonQueryAsync();
    }

    public async Task<CapPerfAlertDto?> AcknowledgeAlertAsync(int alertId)
    {
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_CapPerf_AcknowledgeAlert", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@AlertId", alertId);
        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
            return MapAlert(reader);
        return null;
    }

    public async Task<IEnumerable<CapacityAlertThresholdDto>> GetThresholdsAsync()
    {
        List<CapacityAlertThresholdDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand(
            "SELECT ThresholdId, ThresholdCode, Description, WarnValue, CritValue, Unit, IsActive, ModifiedAt FROM dbo.CapacityAlertThreshold ORDER BY ThresholdCode",
            connection);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new CapacityAlertThresholdDto
            {
                ThresholdId = Convert.ToInt32(reader["ThresholdId"]),
                ThresholdCode = reader["ThresholdCode"].ToString()!,
                Description = reader["Description"].ToString()!,
                WarnValue = Convert.ToDecimal(reader["WarnValue"]),
                CritValue = Convert.ToDecimal(reader["CritValue"]),
                Unit = reader["Unit"].ToString()!,
                IsActive = Convert.ToBoolean(reader["IsActive"]),
                ModifiedAt = Convert.ToDateTime(reader["ModifiedAt"])
            });
        }
        return results;
    }

    public async Task<CapacityAlertThresholdDto?> UpdateThresholdAsync(string thresholdCode, UpdateThresholdRequestDto request)
    {
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_CapPerf_UpdateThreshold", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@ThresholdCode", thresholdCode);
        command.Parameters.AddWithValue("@WarnValue", request.WarnValue);
        command.Parameters.AddWithValue("@CritValue", request.CritValue);
        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return new CapacityAlertThresholdDto
            {
                ThresholdId = Convert.ToInt32(reader["ThresholdId"]),
                ThresholdCode = reader["ThresholdCode"].ToString()!,
                Description = reader["Description"].ToString()!,
                WarnValue = Convert.ToDecimal(reader["WarnValue"]),
                CritValue = Convert.ToDecimal(reader["CritValue"]),
                Unit = reader["Unit"].ToString()!,
                IsActive = Convert.ToBoolean(reader["IsActive"]),
                ModifiedAt = Convert.ToDateTime(reader["ModifiedAt"])
            };
        }
        return null;
    }

    public async Task CaptureMetricsAsync()
    {
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Cap_CaptureMetricSnapshot", connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 120
        };
        await command.ExecuteNonQueryAsync();
    }

    public async Task<byte[]> ExportCapacitySummaryExcelAsync()
        => ToExcel(new[] { await GetCapacityPlanningSummaryAsync() }, "CapacitySummary");

    public async Task<byte[]> ExportSqlPerformanceExcelAsync(int topN = 25)
        => ToExcel(await GetSlowQueryStatisticsAsync(topN), "SqlPerformance");

    public async Task<byte[]> ExportStorageExcelAsync()
        => ToExcel(await GetStorageUtilizationAsync(), "StorageUtilization");

    public async Task<byte[]> ExportResourceExcelAsync()
        => ToExcel(new[] { await GetResourceConsumptionAsync() }, "ResourceConsumption");

    public async Task<byte[]> ExportAlertHistoryExcelAsync(int daysBack = 30)
        => ToExcel(await GetAlertHistoryAsync(daysBack), "AlertHistory");

    public async Task<string> ExportCapacitySummaryCsvAsync()
        => ToCsv(new[] { await GetCapacityPlanningSummaryAsync() });

    public async Task<string> ExportSqlPerformanceCsvAsync(int topN = 25)
        => ToCsv(await GetSlowQueryStatisticsAsync(topN));

    public async Task<string> ExportStorageCsvAsync()
        => ToCsv(await GetStorageUtilizationAsync());

    public async Task<string> ExportResourceCsvAsync()
        => ToCsv(new[] { await GetResourceConsumptionAsync() });

    public async Task<string> ExportAlertHistoryCsvAsync(int daysBack = 30)
        => ToCsv(await GetAlertHistoryAsync(daysBack));

    private static CapacityPlanningSummaryDto MapCapacitySummary(SqlDataReader reader) => new()
    {
        DatabaseName = reader["DatabaseName"].ToString()!,
        CurrentSizeMB = Convert.ToDecimal(reader["CurrentSizeMB"]),
        UsedSpaceMB = Convert.ToDecimal(reader["UsedSpaceMB"]),
        UsedPercent = Convert.ToDecimal(reader["UsedPercent"]),
        AvgDailyGrowthMB = GetNullableDecimal(reader, "AvgDailyGrowthMB"),
        ProjectedSize30dMB = GetNullableDecimal(reader, "ProjectedSize30dMB"),
        ProjectedSize90dMB = GetNullableDecimal(reader, "ProjectedSize90dMB"),
        DaysUntilFull = GetNullableInt32(reader, "DaysUntilFull"),
        ForecastMethod = reader["ForecastMethod"].ToString()!,
        ForecastCapturedAt = GetNullableDateTime(reader, "ForecastCapturedAt"),
        OpenCapacityAlerts = Convert.ToInt32(reader["OpenCapacityAlerts"]),
        CapturedAtUtc = Convert.ToDateTime(reader["CapturedAtUtc"])
    };

    private static ResourceConsumptionDto MapResource(SqlDataReader reader) => new()
    {
        DatabaseName = reader["DatabaseName"].ToString()!,
        CpuCount = Convert.ToInt32(reader["CpuCount"]),
        PhysicalMemoryMB = Convert.ToDecimal(reader["PhysicalMemoryMB"]),
        SqlCommittedMemoryMB = Convert.ToDecimal(reader["SqlCommittedMemoryMB"]),
        DatabaseSizeMB = Convert.ToDecimal(reader["DatabaseSizeMB"]),
        UserSessions = Convert.ToInt32(reader["UserSessions"]),
        ActiveRequests = Convert.ToInt32(reader["ActiveRequests"]),
        BlockedRequests = Convert.ToInt32(reader["BlockedRequests"]),
        SignalWaitPercent = GetNullableDecimal(reader, "SignalWaitPercent"),
        CapturedAtUtc = Convert.ToDateTime(reader["CapturedAtUtc"])
    };

    private static WaitStatisticDto MapWait(SqlDataReader reader) => new()
    {
        WaitType = reader["WaitType"].ToString()!,
        WaitingTasksCount = Convert.ToInt64(reader["WaitingTasksCount"]),
        WaitTimeMs = Convert.ToInt64(reader["WaitTimeMs"]),
        MaxWaitTimeMs = Convert.ToInt64(reader["MaxWaitTimeMs"]),
        SignalWaitTimeMs = Convert.ToInt64(reader["SignalWaitTimeMs"]),
        ResourceWaitTimeMs = Convert.ToInt64(reader["ResourceWaitTimeMs"]),
        WaitPercent = Convert.ToDecimal(reader["WaitPercent"])
    };

    private static CapPerfAlertDto MapAlert(SqlDataReader reader) => new()
    {
        AlertId = Convert.ToInt32(reader["AlertId"]),
        AlertType = reader["AlertType"].ToString()!,
        Severity = reader["Severity"].ToString()!,
        MessageText = reader["MessageText"].ToString()!,
        MetricValue = GetNullableDecimal(reader, "MetricValue"),
        ThresholdValue = GetNullableDecimal(reader, "ThresholdValue"),
        CapturedAt = Convert.ToDateTime(reader["CapturedAt"]),
        IsAcknowledged = Convert.ToBoolean(reader["IsAcknowledged"])
    };

    private static byte[] ToExcel<T>(IEnumerable<T> rows, string sheetName)
    {
        using XLWorkbook workbook = new();
        var ws = workbook.Worksheets.Add(sheetName.Length > 31 ? sheetName[..31] : sheetName);
        var list = rows.ToList();
        if (list.Count == 0)
        {
            ws.Cell(1, 1).Value = "No data";
        }
        else
        {
            var props = typeof(T).GetProperties();
            for (int c = 0; c < props.Length; c++)
            {
                ws.Cell(1, c + 1).Value = props[c].Name;
                ws.Cell(1, c + 1).Style.Font.Bold = true;
            }
            for (int r = 0; r < list.Count; r++)
                for (int c = 0; c < props.Length; c++)
                    ws.Cell(r + 2, c + 1).Value = props[c].GetValue(list[r])?.ToString() ?? string.Empty;
            ws.Columns().AdjustToContents();
        }
        using MemoryStream stream = new();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }

    private static string ToCsv<T>(IEnumerable<T> rows)
    {
        var sb = new StringBuilder();
        var props = typeof(T).GetProperties();
        sb.AppendLine(string.Join(",", props.Select(p => EscapeCsv(p.Name))));
        foreach (var item in rows)
            sb.AppendLine(string.Join(",", props.Select(p => EscapeCsv(Convert.ToString(p.GetValue(item), CultureInfo.InvariantCulture)))));
        return sb.ToString();
    }

    private static string EscapeCsv(string? value)
    {
        if (string.IsNullOrEmpty(value)) return string.Empty;
        if (value.Contains(',') || value.Contains('"') || value.Contains('\n') || value.Contains('\r'))
            return '"' + value.Replace("\"", "\"\"") + '"';
        return value;
    }

    private static string? GetNullableString(SqlDataReader reader, string name)
        => reader[name] is DBNull ? null : reader[name].ToString();
    private static DateTime? GetNullableDateTime(SqlDataReader reader, string name)
        => reader[name] is DBNull ? null : Convert.ToDateTime(reader[name]);
    private static int? GetNullableInt32(SqlDataReader reader, string name)
        => reader[name] is DBNull ? null : Convert.ToInt32(reader[name]);
    private static long? GetNullableInt64(SqlDataReader reader, string name)
        => reader[name] is DBNull ? null : Convert.ToInt64(reader[name]);
    private static decimal? GetNullableDecimal(SqlDataReader reader, string name)
        => reader[name] is DBNull ? null : Convert.ToDecimal(reader[name]);
}
