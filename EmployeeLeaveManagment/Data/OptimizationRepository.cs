using ClosedXML.Excel;
using EmployeeLeaveManagment.DTOs;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Globalization;
using System.Text;

namespace EmployeeLeaveManagment.Data;

public class OptimizationRepository : IOptimizationRepository
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public OptimizationRepository(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<PerformanceSummaryDto> GetPerformanceSummaryAsync()
    {
        PerformanceSummaryDto dto = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Opt_Report_PerformanceSummary", connection) { CommandType = CommandType.StoredProcedure };
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            dto.DatabaseName = reader["DatabaseName"].ToString()!;
            dto.TotalSizeMB = Convert.ToDecimal(reader["TotalSizeMB"]);
            dto.DataSizeMB = Convert.ToDecimal(reader["DataSizeMB"]);
            dto.LogSizeMB = Convert.ToDecimal(reader["LogSizeMB"]);
            dto.UsedSpaceMB = Convert.ToDecimal(reader["UsedSpaceMB"]);
            dto.UsedPercent = Convert.ToDecimal(reader["UsedPercent"]);
            dto.ActiveUserSessions = Convert.ToInt32(reader["ActiveUserSessions"]);
            dto.SuspendedRequests = Convert.ToInt32(reader["SuspendedRequests"]);
            dto.BlockedRequests = Convert.ToInt32(reader["BlockedRequests"]);
            dto.PartitionedTables = Convert.ToInt32(reader["PartitionedTables"]);
            dto.FailedOptJobsLast7Days = Convert.ToInt32(reader["FailedOptJobsLast7Days"]);
            dto.CapturedAtUtc = Convert.ToDateTime(reader["CapturedAtUtc"]);
        }

        return dto;
    }

    public async Task<IEnumerable<QueryExecutionStatDto>> GetQueryExecutionStatsAsync(int topN = 25)
    {
        List<QueryExecutionStatDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Opt_Report_QueryExecutionStats", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@TopN", topN);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new QueryExecutionStatDto
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

    public async Task<IEnumerable<TableGrowthDto>> GetTableGrowthAsync()
    {
        List<TableGrowthDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Opt_Report_TableGrowth", connection) { CommandType = CommandType.StoredProcedure };
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new TableGrowthDto
            {
                SchemaName = reader["SchemaName"].ToString()!,
                TableName = reader["TableName"].ToString()!,
                RowCounts = Convert.ToInt64(reader["RowCounts"]),
                TotalSpaceMB = Convert.ToDecimal(reader["TotalSpaceMB"]),
                UsedSpaceMB = Convert.ToDecimal(reader["UsedSpaceMB"]),
                DataSpaceMB = Convert.ToDecimal(reader["DataSpaceMB"]),
                IsPartitioned = Convert.ToInt32(reader["IsPartitioned"]) == 1,
                PartitionSchemeOrFilegroup = reader["PartitionSchemeOrFilegroup"].ToString()!,
                PartitionCount = Convert.ToInt32(reader["PartitionCount"])
            });
        }

        return results;
    }

    public async Task<IEnumerable<StorageUtilizationDto>> GetStorageUtilizationAsync()
    {
        List<StorageUtilizationDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Opt_Report_StorageUtilization", connection) { CommandType = CommandType.StoredProcedure };
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new StorageUtilizationDto
            {
                FilegroupName = GetNullableString(reader, "FilegroupName"),
                LogicalFileName = reader["LogicalFileName"].ToString()!,
                PhysicalPath = reader["PhysicalPath"].ToString()!,
                FileType = reader["FileType"].ToString()!,
                SizeMB = Convert.ToDecimal(reader["SizeMB"]),
                UsedMB = Convert.ToDecimal(reader["UsedMB"]),
                FreeMB = Convert.ToDecimal(reader["FreeMB"]),
                UsedPercent = Convert.ToDecimal(reader["UsedPercent"]),
                GrowthSetting = Convert.ToInt32(reader["GrowthSetting"]),
                GrowthUnit = reader["GrowthUnit"].ToString()!
            });
        }

        return results;
    }

    public async Task<IEnumerable<OptIndexHealthDto>> GetIndexHealthAsync(int minPageCount = 50)
    {
        List<OptIndexHealthDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Opt_Report_IndexHealth", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@MinPageCount", minPageCount);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new OptIndexHealthDto
            {
                SchemaName = reader["SchemaName"].ToString()!,
                TableName = reader["TableName"].ToString()!,
                IndexName = reader["IndexName"].ToString()!,
                PartitionNumber = Convert.ToInt32(reader["PartitionNumber"]),
                IndexType = reader["IndexType"].ToString()!,
                FragmentationPercent = Convert.ToDecimal(reader["FragmentationPercent"]),
                PageCount = Convert.ToInt64(reader["PageCount"]),
                AvgPageSpaceUsedPercent = reader["AvgPageSpaceUsedPercent"] is DBNull
                    ? null
                    : Convert.ToDouble(reader["AvgPageSpaceUsedPercent"]),
                RecommendedAction = reader["RecommendedAction"].ToString()!,
                IsPartitionAligned = Convert.ToInt32(reader["IsPartitionAligned"]) == 1,
                PartitionScheme = GetNullableString(reader, "PartitionScheme")
            });
        }

        return results;
    }

    public async Task<IEnumerable<PartitionInfoDto>> GetPartitionInfoAsync(string? tableName = null)
    {
        List<PartitionInfoDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Opt_Report_PartitionInfo", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@TableName", (object?)tableName ?? DBNull.Value);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new PartitionInfoDto
            {
                SchemaName = reader["SchemaName"].ToString()!,
                TableName = reader["TableName"].ToString()!,
                IndexName = GetNullableString(reader, "IndexName"),
                PartitionNumber = Convert.ToInt32(reader["PartitionNumber"]),
                FilegroupName = reader["FilegroupName"].ToString()!,
                RowCounts = Convert.ToInt64(reader["RowCounts"]),
                LowerBoundaryInclusive = reader["LowerBoundaryInclusive"] is DBNull ? null : reader["LowerBoundaryInclusive"],
                UpperBoundaryExclusive = reader["UpperBoundaryExclusive"] is DBNull ? null : reader["UpperBoundaryExclusive"],
                PartitionFunction = reader["PartitionFunction"].ToString()!,
                PartitionScheme = reader["PartitionScheme"].ToString()!,
                TotalSpaceMB = reader["TotalSpaceMB"] is DBNull ? null : Convert.ToDecimal(reader["TotalSpaceMB"])
            });
        }

        return results;
    }

    public async Task<OptHealthCheckDto> GetHealthCheckAsync()
    {
        OptHealthCheckDto dto = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Opt_DatabaseHealthCheck", connection) { CommandType = CommandType.StoredProcedure };
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            dto.DatabaseName = reader["DatabaseName"].ToString()!;
            dto.HealthStatus = reader["HealthStatus"].ToString()!;
            dto.Details = reader["Details"].ToString()!;
            dto.CapturedAtUtc = Convert.ToDateTime(reader["CapturedAtUtc"]);
        }

        return dto;
    }

    public async Task<byte[]> ExportPerformanceSummaryExcelAsync()
    {
        var summary = await GetPerformanceSummaryAsync();
        return ToExcel(new[] { summary }, "PerformanceSummary");
    }

    public async Task<byte[]> ExportQueryExecutionStatsExcelAsync(int topN = 25)
        => ToExcel(await GetQueryExecutionStatsAsync(topN), "QueryExecutionStats");

    public async Task<byte[]> ExportTableGrowthExcelAsync()
        => ToExcel(await GetTableGrowthAsync(), "TableGrowth");

    public async Task<byte[]> ExportStorageUtilizationExcelAsync()
        => ToExcel(await GetStorageUtilizationAsync(), "StorageUtilization");

    public async Task<byte[]> ExportIndexHealthExcelAsync(int minPageCount = 50)
        => ToExcel(await GetIndexHealthAsync(minPageCount), "IndexHealth");

    public async Task<byte[]> ExportPartitionInfoExcelAsync(string? tableName = null)
        => ToExcel(await GetPartitionInfoAsync(tableName), "PartitionInfo");

    public async Task<string> ExportPerformanceSummaryCsvAsync()
        => ToCsv(new[] { await GetPerformanceSummaryAsync() });

    public async Task<string> ExportQueryExecutionStatsCsvAsync(int topN = 25)
        => ToCsv(await GetQueryExecutionStatsAsync(topN));

    public async Task<string> ExportTableGrowthCsvAsync()
        => ToCsv(await GetTableGrowthAsync());

    public async Task<string> ExportStorageUtilizationCsvAsync()
        => ToCsv(await GetStorageUtilizationAsync());

    public async Task<string> ExportIndexHealthCsvAsync(int minPageCount = 50)
        => ToCsv(await GetIndexHealthAsync(minPageCount));

    public async Task<string> ExportPartitionInfoCsvAsync(string? tableName = null)
        => ToCsv(await GetPartitionInfoAsync(tableName));

    private static byte[] ToExcel<T>(IEnumerable<T> rows, string sheetName)
    {
        using XLWorkbook workbook = new();
        IXLWorksheet worksheet = workbook.Worksheets.Add(sheetName);
        var list = rows.ToList();
        if (list.Count == 0)
        {
            worksheet.Cell(1, 1).Value = "No data";
        }
        else
        {
            var props = typeof(T).GetProperties();
            for (int c = 0; c < props.Length; c++)
            {
                worksheet.Cell(1, c + 1).Value = props[c].Name;
                worksheet.Cell(1, c + 1).Style.Font.Bold = true;
            }

            for (int r = 0; r < list.Count; r++)
            {
                for (int c = 0; c < props.Length; c++)
                {
                    object? value = props[c].GetValue(list[r]);
                    worksheet.Cell(r + 2, c + 1).Value = value?.ToString() ?? string.Empty;
                }
            }

            worksheet.Columns().AdjustToContents();
        }

        using MemoryStream stream = new();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }

    private static string ToCsv<T>(IEnumerable<T> rows)
    {
        StringBuilder sb = new();
        var list = rows.ToList();
        var props = typeof(T).GetProperties();

        sb.AppendLine(string.Join(",", props.Select(p => EscapeCsv(p.Name))));
        foreach (var item in list)
        {
            sb.AppendLine(string.Join(",", props.Select(p =>
                EscapeCsv(Convert.ToString(p.GetValue(item), CultureInfo.InvariantCulture)))));
        }

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

    private static long? GetNullableInt64(SqlDataReader reader, string name)
        => reader[name] is DBNull ? null : Convert.ToInt64(reader[name]);
}
