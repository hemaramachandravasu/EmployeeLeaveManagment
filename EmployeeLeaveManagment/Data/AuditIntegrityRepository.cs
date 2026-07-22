using ClosedXML.Excel;
using EmployeeLeaveManagment.DTOs;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Globalization;
using System.Text;

namespace EmployeeLeaveManagment.Data;

public class AuditIntegrityRepository : IAuditIntegrityRepository
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public AuditIntegrityRepository(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IntegrityCheckResultDto> RunAllIntegrityChecksAsync(int? balanceYear = null)
    {
        IntegrityCheckResultDto dto = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Integrity_RunAllChecks", connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 120
        };
        command.Parameters.AddWithValue("@BalanceYear", (object?)balanceYear ?? DBNull.Value);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            dto.RunId = Convert.ToInt32(reader["RunId"]);
            dto.ChecksRun = Convert.ToInt32(reader["ChecksRun"]);
            dto.ViolationsFound = Convert.ToInt32(reader["ViolationsFound"]);
            dto.Status = reader["Status"].ToString()!;
        }

        return dto;
    }

    public async Task<IEnumerable<IntegrityViolationDto>> GetIntegrityViolationsAsync(int daysBack = 30, bool unresolvedOnly = false, string? severity = null)
    {
        List<IntegrityViolationDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Report_IntegrityViolations", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@DaysBack", daysBack);
        command.Parameters.AddWithValue("@UnresolvedOnly", unresolvedOnly);
        command.Parameters.AddWithValue("@Severity", (object?)severity ?? DBNull.Value);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
            results.Add(MapViolation(reader));

        return results;
    }

    public async Task<IEnumerable<AuditSummaryDto>> GetAuditSummaryAsync(int daysBack = 30)
    {
        List<AuditSummaryDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Report_AuditSummary", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@DaysBack", daysBack);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new AuditSummaryDto
            {
                TableName = reader["TableName"].ToString()!,
                ActionType = reader["ActionType"].ToString()!,
                EventCount = Convert.ToInt32(reader["EventCount"]),
                DistinctActors = Convert.ToInt32(reader["DistinctActors"]),
                FirstEventAt = GetNullableDateTime(reader, "FirstEventAt"),
                LastEventAt = GetNullableDateTime(reader, "LastEventAt")
            });
        }

        return results;
    }

    public async Task<DataQualityStatusDto> GetDataQualityStatusAsync()
    {
        DataQualityStatusDto dto = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Report_DataQualityStatus", connection) { CommandType = CommandType.StoredProcedure };
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            dto.DataQualityStatus = reader["DataQualityStatus"].ToString()!;
            dto.OpenCritical = Convert.ToInt32(reader["OpenCritical"]);
            dto.OpenHigh = Convert.ToInt32(reader["OpenHigh"]);
            dto.OpenMedium = Convert.ToInt32(reader["OpenMedium"]);
            dto.OpenLow = Convert.ToInt32(reader["OpenLow"]);
            dto.AuditEventsLast7Days = Convert.ToInt32(reader["AuditEventsLast7Days"]);
            dto.UserActivityLast7Days = Convert.ToInt32(reader["UserActivityLast7Days"]);
            dto.ExceptionsLast7Days = Convert.ToInt32(reader["ExceptionsLast7Days"]);
            dto.LastComplianceRunStatus = GetNullableString(reader, "LastComplianceRunStatus");
            dto.LastComplianceRunAt = GetNullableDateTime(reader, "LastComplianceRunAt");
            dto.ActiveHolidays = Convert.ToInt32(reader["ActiveHolidays"]);
            dto.ActivePolicies = Convert.ToInt32(reader["ActivePolicies"]);
            dto.CapturedAtUtc = Convert.ToDateTime(reader["CapturedAtUtc"]);
        }

        return dto;
    }

    public async Task<IEnumerable<UserActivitySummaryDto>> GetUserActivitySummaryAsync(int daysBack = 30)
    {
        List<UserActivitySummaryDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Report_UserActivitySummary", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@DaysBack", daysBack);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new UserActivitySummaryDto
            {
                UserName = reader["UserName"].ToString()!,
                ActivityType = reader["ActivityType"].ToString()!,
                ActivityCount = Convert.ToInt32(reader["ActivityCount"]),
                SuccessCount = Convert.ToInt32(reader["SuccessCount"]),
                FailureCount = Convert.ToInt32(reader["FailureCount"]),
                FirstActivityAt = GetNullableDateTime(reader, "FirstActivityAt"),
                LastActivityAt = GetNullableDateTime(reader, "LastActivityAt")
            });
        }

        return results;
    }

    public async Task<ComplianceStatusDto> GetComplianceStatusAsync()
    {
        ComplianceStatusDto dto = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Monitor_ComplianceStatus", connection) { CommandType = CommandType.StoredProcedure };
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            dto.ComplianceStatus = reader["ComplianceStatus"].ToString()!;
            dto.OpenViolations = Convert.ToInt32(reader["OpenViolations"]);
            dto.OpenCriticalViolations = Convert.ToInt32(reader["OpenCriticalViolations"]);
            dto.FailedRunsLast24h = Convert.ToInt32(reader["FailedRunsLast24h"]);
            dto.ExceptionsLast24h = Convert.ToInt32(reader["ExceptionsLast24h"]);
            dto.LastSuccessfulCheckAt = GetNullableDateTime(reader, "LastSuccessfulCheckAt");
            dto.AuditEventsLast24h = Convert.ToInt32(reader["AuditEventsLast24h"]);
            dto.UserActivityLast24h = Convert.ToInt32(reader["UserActivityLast24h"]);
            dto.CapturedAtUtc = Convert.ToDateTime(reader["CapturedAtUtc"]);
        }

        return dto;
    }

    public async Task<IEnumerable<ComplianceRunDto>> GetFailedValidationChecksAsync(int hoursBack = 48)
    {
        List<ComplianceRunDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Monitor_FailedValidationChecks", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@HoursBack", hoursBack);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
            results.Add(MapComplianceRun(reader));

        return results;
    }

    public async Task<IEnumerable<DatabaseExceptionDto>> GetDatabaseExceptionsAsync(int hoursBack = 48)
    {
        List<DatabaseExceptionDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Monitor_DatabaseExceptions", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@HoursBack", hoursBack);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new DatabaseExceptionDto
            {
                ExceptionId = Convert.ToInt64(reader["ExceptionId"]),
                SourceProc = GetNullableString(reader, "SourceProc"),
                ErrorNumber = GetNullableInt32(reader, "ErrorNumber"),
                ErrorSeverity = GetNullableInt32(reader, "ErrorSeverity"),
                ErrorState = GetNullableInt32(reader, "ErrorState"),
                ErrorMessage = reader["ErrorMessage"].ToString()!,
                CapturedAt = Convert.ToDateTime(reader["CapturedAt"]),
                ContextInfo = GetNullableString(reader, "ContextInfo")
            });
        }

        return results;
    }

    public async Task<IEnumerable<ComplianceRunDto>> GetScheduledAuditJobHistoryAsync(int hoursBack = 72)
    {
        List<ComplianceRunDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Monitor_ScheduledAuditJobs", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@HoursBack", hoursBack);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        /* First result set may be Agent history with different shape — skip to ComplianceRunLog set */
        do
        {
            if (!reader.HasRows) continue;
            // Detect ComplianceRunLog shape by column presence
            try
            {
                _ = reader.GetOrdinal("RunId");
            }
            catch (IndexOutOfRangeException)
            {
                continue;
            }

            while (await reader.ReadAsync())
                results.Add(MapComplianceRun(reader));
        } while (await reader.NextResultAsync());

        return results;
    }

    public async Task<IntegrityViolationDto?> ResolveViolationAsync(long violationId, ResolveViolationRequestDto request)
    {
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Compliance_ResolveViolation", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@ViolationId", violationId);
        command.Parameters.AddWithValue("@ResolvedBy", request.ResolvedBy);
        command.Parameters.AddWithValue("@ResolutionNotes", (object?)request.ResolutionNotes ?? DBNull.Value);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
            return MapViolation(reader);

        return null;
    }

    public async Task<long> LogUserActivityAsync(LogUserActivityRequestDto request)
    {
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Audit_LogUserActivity", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@UserId", (object?)request.UserId ?? DBNull.Value);
        command.Parameters.AddWithValue("@UserName", (object?)request.UserName ?? DBNull.Value);
        command.Parameters.AddWithValue("@ActivityType", request.ActivityType);
        command.Parameters.AddWithValue("@EntityName", (object?)request.EntityName ?? DBNull.Value);
        command.Parameters.AddWithValue("@EntityId", (object?)request.EntityId ?? DBNull.Value);
        command.Parameters.AddWithValue("@ActivityDetail", (object?)request.ActivityDetail ?? DBNull.Value);
        command.Parameters.AddWithValue("@IpAddress", (object?)request.IpAddress ?? DBNull.Value);
        command.Parameters.AddWithValue("@Success", request.Success);

        object? result = await command.ExecuteScalarAsync();
        return result is null or DBNull ? 0L : Convert.ToInt64(result);
    }

    public async Task<byte[]> ExportIntegrityViolationsExcelAsync(int daysBack = 30, bool unresolvedOnly = false)
        => ToExcel(await GetIntegrityViolationsAsync(daysBack, unresolvedOnly), "IntegrityViolations");

    public async Task<byte[]> ExportAuditSummaryExcelAsync(int daysBack = 30)
        => ToExcel(await GetAuditSummaryAsync(daysBack), "AuditSummary");

    public async Task<byte[]> ExportDataQualityExcelAsync()
        => ToExcel(new[] { await GetDataQualityStatusAsync() }, "DataQuality");

    public async Task<byte[]> ExportUserActivityExcelAsync(int daysBack = 30)
        => ToExcel(await GetUserActivitySummaryAsync(daysBack), "UserActivity");

    public async Task<byte[]> ExportComplianceStatusExcelAsync()
        => ToExcel(new[] { await GetComplianceStatusAsync() }, "ComplianceStatus");

    public async Task<string> ExportIntegrityViolationsCsvAsync(int daysBack = 30, bool unresolvedOnly = false)
        => ToCsv(await GetIntegrityViolationsAsync(daysBack, unresolvedOnly));

    public async Task<string> ExportAuditSummaryCsvAsync(int daysBack = 30)
        => ToCsv(await GetAuditSummaryAsync(daysBack));

    public async Task<string> ExportDataQualityCsvAsync()
        => ToCsv(new[] { await GetDataQualityStatusAsync() });

    public async Task<string> ExportUserActivityCsvAsync(int daysBack = 30)
        => ToCsv(await GetUserActivitySummaryAsync(daysBack));

    public async Task<string> ExportComplianceStatusCsvAsync()
        => ToCsv(new[] { await GetComplianceStatusAsync() });

    private static IntegrityViolationDto MapViolation(SqlDataReader reader) => new()
    {
        ViolationId = Convert.ToInt64(reader["ViolationId"]),
        RunId = GetNullableInt32(reader, "RunId"),
        CheckCode = reader["CheckCode"].ToString()!,
        Severity = reader["Severity"].ToString()!,
        EntityName = reader["EntityName"].ToString()!,
        EntityId = GetNullableInt32(reader, "EntityId"),
        EmployeeId = GetNullableInt32(reader, "EmployeeId"),
        ViolationDetail = reader["ViolationDetail"].ToString()!,
        DetectedAt = Convert.ToDateTime(reader["DetectedAt"]),
        IsResolved = Convert.ToBoolean(reader["IsResolved"]),
        ResolvedAt = GetNullableDateTime(reader, "ResolvedAt"),
        ResolvedBy = GetNullableString(reader, "ResolvedBy"),
        ResolutionNotes = GetNullableString(reader, "ResolutionNotes")
    };

    private static ComplianceRunDto MapComplianceRun(SqlDataReader reader) => new()
    {
        RunId = Convert.ToInt32(reader["RunId"]),
        JobName = reader["JobName"].ToString()!,
        StepName = reader["StepName"].ToString()!,
        StartTime = Convert.ToDateTime(reader["StartTime"]),
        EndTime = GetNullableDateTime(reader, "EndTime"),
        Status = reader["Status"].ToString()!,
        ChecksRun = GetNullableInt32(reader, "ChecksRun"),
        ViolationsFound = GetNullableInt32(reader, "ViolationsFound"),
        Details = GetNullableString(reader, "Details"),
        ErrorMessage = HasColumn(reader, "ErrorMessage") ? GetNullableString(reader, "ErrorMessage") : null
    };

    private static bool HasColumn(SqlDataReader reader, string name)
    {
        for (int i = 0; i < reader.FieldCount; i++)
            if (string.Equals(reader.GetName(i), name, StringComparison.OrdinalIgnoreCase))
                return true;
        return false;
    }

    private static byte[] ToExcel<T>(IEnumerable<T> rows, string sheetName)
    {
        using XLWorkbook workbook = new();
        IXLWorksheet worksheet = workbook.Worksheets.Add(sheetName.Length > 31 ? sheetName[..31] : sheetName);
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

    private static int? GetNullableInt32(SqlDataReader reader, string name)
        => reader[name] is DBNull ? null : Convert.ToInt32(reader[name]);
}
