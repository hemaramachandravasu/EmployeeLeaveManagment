using ClosedXML.Excel;
using EmployeeLeaveManagment.DTOs;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Globalization;
using System.Text;

namespace EmployeeLeaveManagment.Data;

public class MigrationFrameworkRepository : IMigrationFrameworkRepository
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public MigrationFrameworkRepository(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IEnumerable<SchemaMigrationDto>> GetMigrationHistoryAsync(string? status = null, int topN = 100)
    {
        List<SchemaMigrationDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Report_MigrationHistory", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@TopN", topN);
        command.Parameters.AddWithValue("@Status", (object?)status ?? DBNull.Value);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            results.Add(MapMigration(reader));
        return results;
    }

    public async Task<SchemaMigrationDto> ApplyMigrationAsync(ApplyMigrationRequestDto request)
    {
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Mig_Apply", connection) { CommandType = CommandType.StoredProcedure, CommandTimeout = 120 };
        command.Parameters.AddWithValue("@VersionNumber", request.VersionNumber);
        command.Parameters.AddWithValue("@MigrationName", request.MigrationName);
        command.Parameters.AddWithValue("@ScriptName", (object?)request.ScriptName ?? DBNull.Value);
        command.Parameters.AddWithValue("@UpSql", request.UpSql);
        command.Parameters.AddWithValue("@DownSql", (object?)request.DownSql ?? DBNull.Value);
        command.Parameters.AddWithValue("@Notes", (object?)request.Notes ?? DBNull.Value);
        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
            return MapMigration(reader);
        throw new InvalidOperationException("Migration apply returned no result.");
    }

    public async Task<SchemaMigrationDto> RollbackMigrationAsync(string? versionNumber = null)
    {
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Mig_Rollback", connection) { CommandType = CommandType.StoredProcedure, CommandTimeout = 120 };
        command.Parameters.AddWithValue("@VersionNumber", (object?)versionNumber ?? DBNull.Value);
        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
            return MapMigration(reader);
        throw new InvalidOperationException("Migration rollback returned no result.");
    }

    public async Task<SchemaMigrationDto> ApplySampleMigrationAsync()
    {
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Mig_ApplySample_0001_0001", connection) { CommandType = CommandType.StoredProcedure, CommandTimeout = 120 };
        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
            return MapMigration(reader);
        throw new InvalidOperationException("Sample migration returned no result.");
    }

    public async Task<IEnumerable<MetaModuleDto>> GetModulesAsync(bool activeOnly = true)
    {
        List<MetaModuleDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Meta_GetModules", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@ActiveOnly", activeOnly);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new MetaModuleDto
            {
                ModuleId = Convert.ToInt32(reader["ModuleId"]),
                ModuleCode = reader["ModuleCode"].ToString()!,
                ModuleName = reader["ModuleName"].ToString()!,
                Description = GetNullableString(reader, "Description"),
                IsActive = Convert.ToBoolean(reader["IsActive"]),
                SortOrder = Convert.ToInt32(reader["SortOrder"])
            });
        }
        return results;
    }

    public async Task<IEnumerable<MetaConfigCategoryDto>> GetConfigCategoriesAsync(string? moduleCode = null, bool activeOnly = true)
    {
        List<MetaConfigCategoryDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Meta_GetConfigCategories", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@ModuleCode", (object?)moduleCode ?? DBNull.Value);
        command.Parameters.AddWithValue("@ActiveOnly", activeOnly);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new MetaConfigCategoryDto
            {
                CategoryId = Convert.ToInt32(reader["CategoryId"]),
                CategoryCode = reader["CategoryCode"].ToString()!,
                CategoryName = reader["CategoryName"].ToString()!,
                ModuleCode = GetNullableString(reader, "ModuleCode"),
                Description = GetNullableString(reader, "Description"),
                IsActive = Convert.ToBoolean(reader["IsActive"])
            });
        }
        return results;
    }

    public async Task<IEnumerable<MetaLookupValueDto>> GetLookupValuesAsync(string categoryCode, bool activeOnly = true)
    {
        List<MetaLookupValueDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Meta_GetLookupValues", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@CategoryCode", categoryCode);
        command.Parameters.AddWithValue("@ActiveOnly", activeOnly);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new MetaLookupValueDto
            {
                LookupId = Convert.ToInt32(reader["LookupId"]),
                CategoryCode = reader["CategoryCode"].ToString()!,
                LookupCode = reader["LookupCode"].ToString()!,
                DisplayName = reader["DisplayName"].ToString()!,
                Description = GetNullableString(reader, "Description"),
                SortOrder = Convert.ToInt32(reader["SortOrder"]),
                IsActive = Convert.ToBoolean(reader["IsActive"])
            });
        }
        return results;
    }

    public async Task<IEnumerable<MetaAuditCategoryDto>> GetAuditCategoriesAsync(bool activeOnly = true)
    {
        List<MetaAuditCategoryDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Meta_GetAuditCategories", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@ActiveOnly", activeOnly);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new MetaAuditCategoryDto
            {
                AuditCategoryId = Convert.ToInt32(reader["AuditCategoryId"]),
                CategoryCode = reader["CategoryCode"].ToString()!,
                CategoryName = reader["CategoryName"].ToString()!,
                Description = GetNullableString(reader, "Description"),
                SeverityDefault = reader["SeverityDefault"].ToString()!,
                IsActive = Convert.ToBoolean(reader["IsActive"])
            });
        }
        return results;
    }

    public async Task<MetaLookupValueDto> UpsertLookupAsync(UpsertLookupRequestDto request)
    {
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Meta_UpsertLookupValue", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@CategoryCode", request.CategoryCode);
        command.Parameters.AddWithValue("@LookupCode", request.LookupCode);
        command.Parameters.AddWithValue("@DisplayName", request.DisplayName);
        command.Parameters.AddWithValue("@Description", (object?)request.Description ?? DBNull.Value);
        command.Parameters.AddWithValue("@SortOrder", request.SortOrder);
        command.Parameters.AddWithValue("@IsActive", request.IsActive);
        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return new MetaLookupValueDto
            {
                LookupId = Convert.ToInt32(reader["LookupId"]),
                CategoryCode = reader["CategoryCode"].ToString()!,
                LookupCode = reader["LookupCode"].ToString()!,
                DisplayName = reader["DisplayName"].ToString()!,
                Description = GetNullableString(reader, "Description"),
                SortOrder = Convert.ToInt32(reader["SortOrder"]),
                IsActive = Convert.ToBoolean(reader["IsActive"])
            };
        }
        throw new InvalidOperationException("Upsert lookup returned no result.");
    }

    public async Task<object> RefreshMetadataAsync()
    {
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Meta_RefreshCatalog", connection) { CommandType = CommandType.StoredProcedure };
        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return new
            {
                ActiveModules = Convert.ToInt32(reader["ActiveModules"]),
                ActiveConfigCategories = Convert.ToInt32(reader["ActiveConfigCategories"]),
                ActiveLookups = Convert.ToInt32(reader["ActiveLookups"]),
                ActiveAuditCategories = Convert.ToInt32(reader["ActiveAuditCategories"]),
                RefreshedAtUtc = Convert.ToDateTime(reader["RefreshedAtUtc"])
            };
        }
        return new { Message = "Refreshed" };
    }

    public async Task<MetadataUsageReportDto> GetMetadataUsageAsync()
    {
        MetadataUsageReportDto dto = new();
        List<MetadataUsageItemDto> items = new();
        List<LookupCategoryCountDto> counts = new();

        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Report_MetadataUsage", connection) { CommandType = CommandType.StoredProcedure };
        await using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            items.Add(new MetadataUsageItemDto
            {
                MetaType = reader["MetaType"].ToString()!,
                Code = reader["Code"].ToString()!,
                Name = reader["Name"].ToString()!,
                IsActive = Convert.ToBoolean(reader["IsActive"]),
                CreatedAt = Convert.ToDateTime(reader["CreatedAt"])
            });
        }

        if (await reader.NextResultAsync())
        {
            while (await reader.ReadAsync())
            {
                counts.Add(new LookupCategoryCountDto
                {
                    CategoryCode = reader["CategoryCode"].ToString()!,
                    LookupCount = Convert.ToInt32(reader["LookupCount"]),
                    ActiveCount = Convert.ToInt32(reader["ActiveCount"])
                });
            }
        }

        dto.Items = items;
        dto.LookupCounts = counts;
        return dto;
    }

    public async Task<ValidationRunResultDto> RunValidationAsync(int? balanceYear = null)
    {
        ValidationRunResultDto dto = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Val_RunAllChecks", connection) { CommandType = CommandType.StoredProcedure, CommandTimeout = 180 };
        command.Parameters.AddWithValue("@BalanceYear", (object?)balanceYear ?? DBNull.Value);
        await using var reader = await command.ExecuteReaderAsync();
        // Skip intermediate IssueCount result sets
        do
        {
            if (!reader.HasRows) continue;
            try { _ = reader.GetOrdinal("RunId"); }
            catch (IndexOutOfRangeException) { continue; }

            if (await reader.ReadAsync())
            {
                dto.RunId = Convert.ToInt32(reader["RunId"]);
                dto.ChecksRun = Convert.ToInt32(reader["ChecksRun"]);
                dto.IssuesFound = Convert.ToInt32(reader["IssuesFound"]);
                dto.Status = reader["Status"].ToString()!;
            }
        } while (await reader.NextResultAsync());

        return dto;
    }

    public async Task<IEnumerable<ValidationSummaryDto>> GetValidationSummaryAsync(int daysBack = 30)
    {
        List<ValidationSummaryDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Report_ValidationSummary", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@DaysBack", daysBack);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new ValidationSummaryDto
            {
                CheckCode = reader["CheckCode"].ToString()!,
                Severity = reader["Severity"].ToString()!,
                IssueCount = Convert.ToInt32(reader["IssueCount"]),
                OpenCount = Convert.ToInt32(reader["OpenCount"]),
                FirstDetectedAt = GetNullableDateTime(reader, "FirstDetectedAt"),
                LastDetectedAt = GetNullableDateTime(reader, "LastDetectedAt")
            });
        }
        return results;
    }

    public async Task<IEnumerable<ValidationIssueDto>> GetValidationIssuesAsync(int daysBack = 30, bool unresolvedOnly = false, string? checkCode = null)
    {
        List<ValidationIssueDto> results = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Report_ValidationIssues", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@DaysBack", daysBack);
        command.Parameters.AddWithValue("@UnresolvedOnly", unresolvedOnly);
        command.Parameters.AddWithValue("@CheckCode", (object?)checkCode ?? DBNull.Value);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            results.Add(MapIssue(reader));
        return results;
    }

    public async Task<DataQualityDashboardDto> GetDataQualityDashboardAsync()
    {
        DataQualityDashboardDto dto = new();
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Report_DataQualityDashboard", connection) { CommandType = CommandType.StoredProcedure };
        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            dto.DataQualityStatus = reader["DataQualityStatus"].ToString()!;
            dto.OpenCritical = Convert.ToInt32(reader["OpenCritical"]);
            dto.OpenHigh = Convert.ToInt32(reader["OpenHigh"]);
            dto.OpenMedium = Convert.ToInt32(reader["OpenMedium"]);
            dto.OpenLow = Convert.ToInt32(reader["OpenLow"]);
            dto.AppliedMigrations = Convert.ToInt32(reader["AppliedMigrations"]);
            dto.FailedMigrations = Convert.ToInt32(reader["FailedMigrations"]);
            dto.LastValidationStatus = GetNullableString(reader, "LastValidationStatus");
            dto.LastValidationAt = GetNullableDateTime(reader, "LastValidationAt");
            dto.ActiveLookups = Convert.ToInt32(reader["ActiveLookups"]);
            dto.ActiveModules = Convert.ToInt32(reader["ActiveModules"]);
            dto.CapturedAtUtc = Convert.ToDateTime(reader["CapturedAtUtc"]);
        }
        return dto;
    }

    public async Task<ValidationIssueDto?> ResolveValidationIssueAsync(long validationId, string resolvedBy)
    {
        await using var connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using var command = new SqlCommand("sp_Val_ResolveIssue", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@ValidationId", validationId);
        command.Parameters.AddWithValue("@ResolvedBy", resolvedBy);
        await using var reader = await command.ExecuteReaderAsync();
        if (await reader.ReadAsync())
            return MapIssue(reader);
        return null;
    }

    public async Task<byte[]> ExportMigrationHistoryExcelAsync(int topN = 100)
        => ToExcel(await GetMigrationHistoryAsync(null, topN), "MigrationHistory");
    public async Task<byte[]> ExportValidationSummaryExcelAsync(int daysBack = 30)
        => ToExcel(await GetValidationSummaryAsync(daysBack), "ValidationSummary");
    public async Task<byte[]> ExportValidationIssuesExcelAsync(int daysBack = 30)
        => ToExcel(await GetValidationIssuesAsync(daysBack), "ValidationIssues");
    public async Task<byte[]> ExportDataQualityExcelAsync()
        => ToExcel(new[] { await GetDataQualityDashboardAsync() }, "DataQuality");
    public async Task<byte[]> ExportMetadataUsageExcelAsync()
        => ToExcel((await GetMetadataUsageAsync()).Items, "MetadataUsage");

    public async Task<string> ExportMigrationHistoryCsvAsync(int topN = 100)
        => ToCsv(await GetMigrationHistoryAsync(null, topN));
    public async Task<string> ExportValidationSummaryCsvAsync(int daysBack = 30)
        => ToCsv(await GetValidationSummaryAsync(daysBack));
    public async Task<string> ExportValidationIssuesCsvAsync(int daysBack = 30)
        => ToCsv(await GetValidationIssuesAsync(daysBack));
    public async Task<string> ExportDataQualityCsvAsync()
        => ToCsv(new[] { await GetDataQualityDashboardAsync() });
    public async Task<string> ExportMetadataUsageCsvAsync()
        => ToCsv((await GetMetadataUsageAsync()).Items);

    private static SchemaMigrationDto MapMigration(SqlDataReader reader) => new()
    {
        MigrationId = Convert.ToInt32(reader["MigrationId"]),
        VersionNumber = reader["VersionNumber"].ToString()!,
        MigrationName = reader["MigrationName"].ToString()!,
        ScriptName = GetNullableString(reader, "ScriptName"),
        Status = reader["Status"].ToString()!,
        AppliedAt = Convert.ToDateTime(reader["AppliedAt"]),
        AppliedBy = reader["AppliedBy"].ToString()!,
        DurationMs = GetNullableInt32(reader, "DurationMs"),
        ErrorMessage = GetNullableString(reader, "ErrorMessage"),
        Notes = GetNullableString(reader, "Notes")
    };

    private static ValidationIssueDto MapIssue(SqlDataReader reader) => new()
    {
        ValidationId = Convert.ToInt64(reader["ValidationId"]),
        RunId = GetNullableInt32(reader, "RunId"),
        CheckCode = reader["CheckCode"].ToString()!,
        Severity = reader["Severity"].ToString()!,
        EntityName = reader["EntityName"].ToString()!,
        EntityKey = GetNullableString(reader, "EntityKey"),
        ValidationDetail = reader["ValidationDetail"].ToString()!,
        DetectedAt = Convert.ToDateTime(reader["DetectedAt"]),
        IsResolved = Convert.ToBoolean(reader["IsResolved"]),
        ResolvedAt = GetNullableDateTime(reader, "ResolvedAt"),
        ResolvedBy = GetNullableString(reader, "ResolvedBy")
    };

    private static byte[] ToExcel<T>(IEnumerable<T> rows, string sheetName)
    {
        using var workbook = new XLWorkbook();
        var ws = workbook.Worksheets.Add(sheetName.Length > 31 ? sheetName[..31] : sheetName);
        var list = rows.ToList();
        if (list.Count == 0) ws.Cell(1, 1).Value = "No data";
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
        using var stream = new MemoryStream();
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
}
