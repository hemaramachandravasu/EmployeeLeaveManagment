using ClosedXML.Excel;
using EmployeeLeaveManagment.DTOs;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Text;

namespace EmployeeLeaveManagment.Data;

public class MaintenanceRepository : IMaintenanceRepository
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public MaintenanceRepository(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<DatabaseHealthDashboardDto> GetHealthDashboardAsync()
    {
        DatabaseHealthDashboardDto dashboard = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Monitor_HealthDashboard", connection) { CommandType = CommandType.StoredProcedure };
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            dashboard.DatabaseSize = new DatabaseSizeDto
            {
                DatabaseName = reader["DatabaseName"].ToString()!,
                TotalSizeMB = GetDecimal(reader, "TotalSizeMB"),
                DataSizeMB = GetDecimal(reader, "DataSizeMB"),
                LogSizeMB = GetDecimal(reader, "LogSizeMB"),
                UsedSpaceMB = GetDecimal(reader, "UsedSpaceMB"),
                FreeSpaceMB = GetDecimal(reader, "FreeSpaceMB"),
                UsedPercent = GetDecimal(reader, "UsedPercent")
            };
        }

        await reader.NextResultAsync();
        if (await reader.ReadAsync())
        {
            dashboard.Connections = new ConnectionSummaryDto
            {
                TotalSessions = GetInt32(reader, "TotalSessions"),
                RunningSessions = GetInt32(reader, "RunningSessions"),
                SessionsOnThisDb = GetInt32(reader, "SessionsOnThisDb")
            };
        }

        await reader.NextResultAsync();
        if (await reader.ReadAsync())
        {
            dashboard.Fragmentation = new FragmentationSummaryDto
            {
                AvgFragmentationPercent = GetNullableDecimal(reader, "AvgFragmentationPercent"),
                MaxFragmentationPercent = GetNullableDecimal(reader, "MaxFragmentationPercent"),
                IndexesNeedingRebuild = GetInt32(reader, "IndexesNeedingRebuild"),
                IndexesNeedingReorganize = GetInt32(reader, "IndexesNeedingReorganize")
            };
        }

        await reader.NextResultAsync();
        List<ArchiveEntityStatDto> archiveStats = new();
        while (await reader.ReadAsync())
        {
            archiveStats.Add(new ArchiveEntityStatDto
            {
                EntityName = reader["EntityName"].ToString()!,
                LiveRows = Convert.ToInt32(reader["LiveRows"]),
                ArchivedRows = Convert.ToInt32(reader["ArchivedRows"])
            });
        }
        dashboard.ArchiveStatistics = archiveStats;

        await reader.NextResultAsync();
        List<MaintenanceHistoryDto> maintHistory = new();
        while (await reader.ReadAsync())
        {
            maintHistory.Add(MapMaintenanceHistory(reader));
        }
        dashboard.MaintenanceHistory = maintHistory;

        await reader.NextResultAsync();
        List<ArchiveHistoryDto> archiveHistory = new();
        while (await reader.ReadAsync())
        {
            archiveHistory.Add(new ArchiveHistoryDto
            {
                ArchiveRunId = Convert.ToInt32(reader["ArchiveRunId"]),
                ArchiveBatchId = reader["ArchiveBatchId"] == DBNull.Value ? Guid.Empty : (Guid)reader["ArchiveBatchId"],
                EntityName = reader["EntityName"].ToString()!,
                StartTime = Convert.ToDateTime(reader["StartTime"]),
                EndTime = reader["EndTime"] == DBNull.Value ? null : Convert.ToDateTime(reader["EndTime"]),
                Status = reader["Status"].ToString()!,
                RowsArchived = reader["RowsArchived"] == DBNull.Value ? null : Convert.ToInt32(reader["RowsArchived"]),
                RetentionDays = reader["RetentionDays"] == DBNull.Value ? null : Convert.ToInt32(reader["RetentionDays"])
            });
        }
        dashboard.ArchiveHistory = archiveHistory;

        return dashboard;
    }

    public async Task<DatabaseSizeDto> GetDatabaseSizeAsync()
    {
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Monitor_DatabaseGrowth", connection) { CommandType = CommandType.StoredProcedure };
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            return new DatabaseSizeDto
            {
                DatabaseName = reader["DatabaseName"].ToString()!,
                TotalSizeMB = Convert.ToDecimal(reader["TotalSizeMB"]),
                DataSizeMB = Convert.ToDecimal(reader["DataSizeMB"]),
                LogSizeMB = Convert.ToDecimal(reader["LogSizeMB"]),
                UsedSpaceMB = Convert.ToDecimal(reader["UsedSpaceMB"]),
                FreeSpaceMB = Convert.ToDecimal(reader["FreeSpaceMB"]),
                UsedPercent = Convert.ToDecimal(reader["UsedPercent"])
            };
        }

        return new DatabaseSizeDto();
    }

    public async Task<IEnumerable<MonthlyGrowthDto>> GetMonthlyGrowthAsync(int monthsBack = 12)
    {
        List<MonthlyGrowthDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Report_MonthlyDatabaseGrowth", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@MonthsBack", monthsBack);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
            results.Add(MapMonthlyGrowth(reader));

        if (results.Count == 0 && await reader.NextResultAsync())
        {
            while (await reader.ReadAsync())
                results.Add(MapMonthlyGrowth(reader));
        }

        return results;
    }

    public async Task<IEnumerable<IndexHealthDto>> GetIndexHealthAsync(int minPageCount = 50)
    {
        List<IndexHealthDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Report_IndexHealth", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@MinPageCount", minPageCount);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new IndexHealthDto
            {
                SchemaName = reader["SchemaName"].ToString()!,
                TableName = reader["TableName"].ToString()!,
                IndexName = reader["IndexName"].ToString()!,
                IndexType = reader["IndexType"].ToString()!,
                FragmentationPercent = Convert.ToDecimal(reader["FragmentationPercent"]),
                PageCount = Convert.ToInt64(reader["PageCount"]),
                HealthStatus = reader["HealthStatus"].ToString()!
            });
        }

        return results;
    }

    public async Task<IEnumerable<QueryPerformanceDto>> GetQueryPerformanceAsync(int topN = 25)
    {
        List<QueryPerformanceDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Report_QueryPerformance", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@TopN", topN);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new QueryPerformanceDto
            {
                ExecutionCount = Convert.ToInt64(reader["ExecutionCount"]),
                TotalElapsedMs = Convert.ToInt64(reader["TotalElapsedMs"]),
                AvgElapsedMs = reader["AvgElapsedMs"] == DBNull.Value ? null : Convert.ToInt64(reader["AvgElapsedMs"]),
                TotalCpuMs = Convert.ToInt64(reader["TotalCpuMs"]),
                TotalLogicalReads = Convert.ToInt64(reader["TotalLogicalReads"]),
                LastExecutionTime = reader["LastExecutionTime"] == DBNull.Value ? null : Convert.ToDateTime(reader["LastExecutionTime"]),
                QueryText = reader["QueryText"]?.ToString() ?? string.Empty
            });
        }

        return results;
    }

    public async Task<(IEnumerable<ArchiveSummaryDto> Runs, IEnumerable<ArchiveEntityStatDto> Totals)> GetArchiveSummaryAsync(int daysBack = 90)
    {
        List<ArchiveSummaryDto> runs = new();
        List<ArchiveEntityStatDto> totals = new();

        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Report_ArchiveSummary", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@DaysBack", daysBack);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            runs.Add(new ArchiveSummaryDto
            {
                EntityName = reader["EntityName"].ToString()!,
                RunCount = Convert.ToInt32(reader["RunCount"]),
                SuccessCount = Convert.ToInt32(reader["SuccessCount"]),
                FailedCount = Convert.ToInt32(reader["FailedCount"]),
                TotalRowsArchived = Convert.ToInt32(reader["TotalRowsArchived"]),
                FirstRun = reader["FirstRun"] == DBNull.Value ? null : Convert.ToDateTime(reader["FirstRun"]),
                LastRun = reader["LastRun"] == DBNull.Value ? null : Convert.ToDateTime(reader["LastRun"])
            });
        }

        await reader.NextResultAsync();
        while (await reader.ReadAsync())
        {
            totals.Add(new ArchiveEntityStatDto
            {
                EntityName = reader["EntityName"].ToString()!,
                LiveRows = Convert.ToInt32(reader["LiveRows"]),
                ArchivedRows = Convert.ToInt32(reader["ArchivedRows"]),
                ArchivedPercent = reader["ArchivedPercent"] == DBNull.Value ? null : Convert.ToDecimal(reader["ArchivedPercent"])
            });
        }

        return (runs, totals);
    }

    public async Task<(IEnumerable<MaintenanceExecutionSummaryDto> Summary, IEnumerable<MaintenanceHistoryDto> Detail)> GetMaintenanceExecutionAsync(int daysBack = 90)
    {
        List<MaintenanceExecutionSummaryDto> summary = new();
        List<MaintenanceHistoryDto> detail = new();

        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Report_MaintenanceExecution", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@DaysBack", daysBack);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            summary.Add(new MaintenanceExecutionSummaryDto
            {
                JobName = reader["JobName"].ToString()!,
                StepName = reader["StepName"].ToString()!,
                RunCount = Convert.ToInt32(reader["RunCount"]),
                SuccessCount = Convert.ToInt32(reader["SuccessCount"]),
                FailedCount = Convert.ToInt32(reader["FailedCount"]),
                FirstRun = reader["FirstRun"] == DBNull.Value ? null : Convert.ToDateTime(reader["FirstRun"]),
                LastRun = reader["LastRun"] == DBNull.Value ? null : Convert.ToDateTime(reader["LastRun"]),
                AvgDurationSeconds = reader["AvgDurationSeconds"] == DBNull.Value ? null : Convert.ToInt32(reader["AvgDurationSeconds"])
            });
        }

        await reader.NextResultAsync();
        while (await reader.ReadAsync())
            detail.Add(MapMaintenanceHistory(reader));

        return (summary, detail);
    }

    public async Task<IEnumerable<RetentionConfigDto>> GetRetentionConfigAsync()
    {
        List<RetentionConfigDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Report_GetRetentionConfig", connection) { CommandType = CommandType.StoredProcedure };
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new RetentionConfigDto
            {
                ConfigId = Convert.ToInt32(reader["ConfigId"]),
                EntityName = reader["EntityName"].ToString()!,
                RetentionDays = Convert.ToInt32(reader["RetentionDays"]),
                IsEnabled = Convert.ToBoolean(reader["IsEnabled"]),
                Description = reader["Description"] == DBNull.Value ? null : reader["Description"].ToString(),
                LastModifiedUtc = Convert.ToDateTime(reader["LastModifiedUtc"])
            });
        }

        return results;
    }

    public async Task<RetentionConfigDto?> UpdateRetentionAsync(UpdateRetentionRequestDto request)
    {
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Archive_UpdateRetention", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@EntityName", request.EntityName);
        command.Parameters.AddWithValue("@RetentionDays", request.RetentionDays);
        command.Parameters.AddWithValue("@IsEnabled", request.IsEnabled);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            return new RetentionConfigDto
            {
                ConfigId = 0,
                EntityName = reader["EntityName"].ToString()!,
                RetentionDays = Convert.ToInt32(reader["RetentionDays"]),
                IsEnabled = Convert.ToBoolean(reader["IsEnabled"]),
                Description = reader["Description"] == DBNull.Value ? null : reader["Description"].ToString(),
                LastModifiedUtc = Convert.ToDateTime(reader["LastModifiedUtc"])
            };
        }

        return null;
    }

    public async Task<byte[]> ExportMonthlyGrowthExcelAsync(int monthsBack = 12)
    {
        var data = (await GetMonthlyGrowthAsync(monthsBack)).ToList();
        return BuildExcel("MonthlyGrowth", data, (ws, row, item) =>
        {
            ws.Cell(row, 1).Value = item.Year;
            ws.Cell(row, 2).Value = item.Month;
            ws.Cell(row, 3).Value = item.MonthName;
            ws.Cell(row, 4).Value = item.TotalSizeMB;
            ws.Cell(row, 5).Value = item.UsedSpaceMB;
            ws.Cell(row, 6).Value = item.UsedPercent;
        }, "Year", "Month", "Month Name", "Total Size MB", "Used Space MB", "Used %");
    }

    public async Task<byte[]> ExportIndexHealthExcelAsync(int minPageCount = 50)
    {
        var data = (await GetIndexHealthAsync(minPageCount)).ToList();
        return BuildExcel("IndexHealth", data, (ws, row, item) =>
        {
            ws.Cell(row, 1).Value = item.SchemaName;
            ws.Cell(row, 2).Value = item.TableName;
            ws.Cell(row, 3).Value = item.IndexName;
            ws.Cell(row, 4).Value = item.IndexType;
            ws.Cell(row, 5).Value = item.FragmentationPercent;
            ws.Cell(row, 6).Value = item.PageCount;
            ws.Cell(row, 7).Value = item.HealthStatus;
        }, "Schema", "Table", "Index", "Type", "Fragmentation %", "Pages", "Status");
    }

    public async Task<byte[]> ExportQueryPerformanceExcelAsync(int topN = 25)
    {
        var data = (await GetQueryPerformanceAsync(topN)).ToList();
        return BuildExcel("QueryPerformance", data, (ws, row, item) =>
        {
            ws.Cell(row, 1).Value = item.ExecutionCount;
            ws.Cell(row, 2).Value = item.TotalElapsedMs;
            ws.Cell(row, 3).Value = item.AvgElapsedMs;
            ws.Cell(row, 4).Value = item.TotalCpuMs;
            ws.Cell(row, 5).Value = item.TotalLogicalReads;
            ws.Cell(row, 6).Value = item.LastExecutionTime?.ToString("u");
            ws.Cell(row, 7).Value = item.QueryText;
        }, "Executions", "Total Elapsed Ms", "Avg Elapsed Ms", "Total CPU Ms", "Logical Reads", "Last Execution", "Query");
    }

    public async Task<byte[]> ExportArchiveSummaryExcelAsync(int daysBack = 90)
    {
        var (runs, totals) = await GetArchiveSummaryAsync(daysBack);
        using XLWorkbook workbook = new();

        var summary = workbook.Worksheets.Add("RunSummary");
        WriteHeader(summary, "Entity", "Runs", "Success", "Failed", "Rows Archived", "First Run", "Last Run");
        int row = 2;
        foreach (var item in runs)
        {
            summary.Cell(row, 1).Value = item.EntityName;
            summary.Cell(row, 2).Value = item.RunCount;
            summary.Cell(row, 3).Value = item.SuccessCount;
            summary.Cell(row, 4).Value = item.FailedCount;
            summary.Cell(row, 5).Value = item.TotalRowsArchived;
            summary.Cell(row, 6).Value = item.FirstRun?.ToString("u");
            summary.Cell(row, 7).Value = item.LastRun?.ToString("u");
            row++;
        }

        var totalsSheet = workbook.Worksheets.Add("Totals");
        WriteHeader(totalsSheet, "Entity", "Live Rows", "Archived Rows", "Archived %");
        row = 2;
        foreach (var item in totals)
        {
            totalsSheet.Cell(row, 1).Value = item.EntityName;
            totalsSheet.Cell(row, 2).Value = item.LiveRows;
            totalsSheet.Cell(row, 3).Value = item.ArchivedRows;
            totalsSheet.Cell(row, 4).Value = item.ArchivedPercent;
            row++;
        }

        using MemoryStream stream = new();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }

    public async Task<byte[]> ExportMaintenanceExecutionExcelAsync(int daysBack = 90)
    {
        var (summary, detail) = await GetMaintenanceExecutionAsync(daysBack);
        using XLWorkbook workbook = new();

        var summarySheet = workbook.Worksheets.Add("Summary");
        WriteHeader(summarySheet, "Job", "Step", "Runs", "Success", "Failed", "First Run", "Last Run", "Avg Seconds");
        int row = 2;
        foreach (var item in summary)
        {
            summarySheet.Cell(row, 1).Value = item.JobName;
            summarySheet.Cell(row, 2).Value = item.StepName;
            summarySheet.Cell(row, 3).Value = item.RunCount;
            summarySheet.Cell(row, 4).Value = item.SuccessCount;
            summarySheet.Cell(row, 5).Value = item.FailedCount;
            summarySheet.Cell(row, 6).Value = item.FirstRun?.ToString("u");
            summarySheet.Cell(row, 7).Value = item.LastRun?.ToString("u");
            summarySheet.Cell(row, 8).Value = item.AvgDurationSeconds;
            row++;
        }

        var detailSheet = workbook.Worksheets.Add("Detail");
        WriteHeader(detailSheet, "RunId", "Job", "Step", "Start", "End", "Status", "Details", "Error");
        row = 2;
        foreach (var item in detail)
        {
            detailSheet.Cell(row, 1).Value = item.MaintenanceRunId;
            detailSheet.Cell(row, 2).Value = item.JobName;
            detailSheet.Cell(row, 3).Value = item.StepName;
            detailSheet.Cell(row, 4).Value = item.StartTime.ToString("u");
            detailSheet.Cell(row, 5).Value = item.EndTime?.ToString("u");
            detailSheet.Cell(row, 6).Value = item.Status;
            detailSheet.Cell(row, 7).Value = item.Details;
            detailSheet.Cell(row, 8).Value = item.ErrorMessage;
            row++;
        }

        using MemoryStream stream = new();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }

    public async Task<string> ExportMonthlyGrowthCsvAsync(int monthsBack = 12)
    {
        var data = await GetMonthlyGrowthAsync(monthsBack);
        return ToCsv(data, "Year,Month,MonthName,TotalSizeMB,UsedSpaceMB,UsedPercent",
            x => $"{x.Year},{x.Month},{Escape(x.MonthName)},{x.TotalSizeMB},{x.UsedSpaceMB},{x.UsedPercent}");
    }

    public async Task<string> ExportIndexHealthCsvAsync(int minPageCount = 50)
    {
        var data = await GetIndexHealthAsync(minPageCount);
        return ToCsv(data, "SchemaName,TableName,IndexName,IndexType,FragmentationPercent,PageCount,HealthStatus",
            x => $"{Escape(x.SchemaName)},{Escape(x.TableName)},{Escape(x.IndexName)},{Escape(x.IndexType)},{x.FragmentationPercent},{x.PageCount},{Escape(x.HealthStatus)}");
    }

    public async Task<string> ExportQueryPerformanceCsvAsync(int topN = 25)
    {
        var data = await GetQueryPerformanceAsync(topN);
        return ToCsv(data, "ExecutionCount,TotalElapsedMs,AvgElapsedMs,TotalCpuMs,TotalLogicalReads,LastExecutionTime,QueryText",
            x => $"{x.ExecutionCount},{x.TotalElapsedMs},{x.AvgElapsedMs},{x.TotalCpuMs},{x.TotalLogicalReads},{x.LastExecutionTime:u},{Escape(x.QueryText)}");
    }

    public async Task<string> ExportArchiveSummaryCsvAsync(int daysBack = 90)
    {
        var (runs, _) = await GetArchiveSummaryAsync(daysBack);
        return ToCsv(runs, "EntityName,RunCount,SuccessCount,FailedCount,TotalRowsArchived,FirstRun,LastRun",
            x => $"{Escape(x.EntityName)},{x.RunCount},{x.SuccessCount},{x.FailedCount},{x.TotalRowsArchived},{x.FirstRun:u},{x.LastRun:u}");
    }

    public async Task<string> ExportMaintenanceExecutionCsvAsync(int daysBack = 90)
    {
        var (summary, _) = await GetMaintenanceExecutionAsync(daysBack);
        return ToCsv(summary, "JobName,StepName,RunCount,SuccessCount,FailedCount,FirstRun,LastRun,AvgDurationSeconds",
            x => $"{Escape(x.JobName)},{Escape(x.StepName)},{x.RunCount},{x.SuccessCount},{x.FailedCount},{x.FirstRun:u},{x.LastRun:u},{x.AvgDurationSeconds}");
    }

    private static MonthlyGrowthDto MapMonthlyGrowth(SqlDataReader reader) => new()
    {
        Year = Convert.ToInt32(reader["Year"]),
        Month = Convert.ToInt32(reader["Month"]),
        MonthName = reader["MonthName"].ToString()!,
        TotalSizeMB = reader["TotalSizeMB"] == DBNull.Value ? null : Convert.ToDecimal(reader["TotalSizeMB"]),
        UsedSpaceMB = reader["UsedSpaceMB"] == DBNull.Value ? null : Convert.ToDecimal(reader["UsedSpaceMB"]),
        UsedPercent = reader["UsedPercent"] == DBNull.Value ? null : Convert.ToDecimal(reader["UsedPercent"])
    };

    private static MaintenanceHistoryDto MapMaintenanceHistory(SqlDataReader reader) => new()
    {
        MaintenanceRunId = Convert.ToInt32(reader["MaintenanceRunId"]),
        JobName = reader["JobName"].ToString()!,
        StepName = reader["StepName"].ToString()!,
        StartTime = Convert.ToDateTime(reader["StartTime"]),
        EndTime = reader["EndTime"] == DBNull.Value ? null : Convert.ToDateTime(reader["EndTime"]),
        Status = reader["Status"].ToString()!,
        Details = reader["Details"] == DBNull.Value ? null : reader["Details"].ToString(),
        ErrorMessage = reader["ErrorMessage"] == DBNull.Value ? null : reader["ErrorMessage"].ToString()
    };

    private static byte[] BuildExcel<T>(string sheetName, IList<T> data, Action<IXLWorksheet, int, T> writeRow, params string[] headers)
    {
        using XLWorkbook workbook = new();
        var ws = workbook.Worksheets.Add(sheetName);
        WriteHeader(ws, headers);
        for (int i = 0; i < data.Count; i++)
            writeRow(ws, i + 2, data[i]);
        using MemoryStream stream = new();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }

    private static void WriteHeader(IXLWorksheet ws, params string[] headers)
    {
        for (int i = 0; i < headers.Length; i++)
            ws.Cell(1, i + 1).Value = headers[i];
        ws.Row(1).Style.Font.Bold = true;
    }

    private static string ToCsv<T>(IEnumerable<T> data, string header, Func<T, string> mapRow)
    {
        StringBuilder sb = new();
        sb.AppendLine(header);
        foreach (var item in data)
            sb.AppendLine(mapRow(item));
        return sb.ToString();
    }

    private static string Escape(string? value)
    {
        if (string.IsNullOrEmpty(value)) return string.Empty;
        if (value.Contains(',') || value.Contains('"') || value.Contains('\n'))
            return '"' + value.Replace("\"", "\"\"") + '"';
        return value;
    }

    private static int GetInt32(SqlDataReader reader, string column)
        => reader[column] == DBNull.Value ? 0 : Convert.ToInt32(reader[column]);

    private static decimal GetDecimal(SqlDataReader reader, string column)
        => reader[column] == DBNull.Value ? 0m : Convert.ToDecimal(reader[column]);

    private static decimal? GetNullableDecimal(SqlDataReader reader, string column)
        => reader[column] == DBNull.Value ? null : Convert.ToDecimal(reader[column]);
}
