using ClosedXML.Excel;
using EmployeeLeaveManagment.DTOs;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Text;

namespace EmployeeLeaveManagment.Data;

public class BackupSecurityRepository : IBackupSecurityRepository
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public BackupSecurityRepository(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<BackupStatusDto> GetBackupStatusAsync(string databaseName = "EmployeeLeaveDb")
    {
        BackupStatusDto dto = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Monitor_BackupStatus", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@DatabaseName", databaseName);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            dto.DatabaseName = reader["DatabaseName"].ToString()!;
            dto.RecoveryModel = reader["RecoveryModel"].ToString()!;
            dto.LastFullBackupUtc = GetNullableDateTime(reader, "LastFullBackupUtc");
            dto.LastFullStatus = GetNullableString(reader, "LastFullStatus");
            dto.LastDiffBackupUtc = GetNullableDateTime(reader, "LastDiffBackupUtc");
            dto.LastLogBackupUtc = GetNullableDateTime(reader, "LastLogBackupUtc");
            dto.LastLogStatus = GetNullableString(reader, "LastLogStatus");
            dto.FullBackupAgeHours = GetNullableInt32(reader, "FullBackupAgeHours");
            dto.LogBackupAgeMinutes = GetNullableInt32(reader, "LogBackupAgeMinutes");
            dto.FullBackupHealth = reader["FullBackupHealth"].ToString()!;
            dto.LogBackupHealth = reader["LogBackupHealth"].ToString()!;
            dto.FailedBackupsLast7Days = Convert.ToInt32(reader["FailedBackupsLast7Days"]);
        }

        return dto;
    }

    public async Task<IEnumerable<BackupHistoryDto>> GetBackupHistoryAsync(int daysBack = 30, string databaseName = "EmployeeLeaveDb")
    {
        List<BackupHistoryDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Report_BackupHistory", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@DatabaseName", databaseName);
        command.Parameters.AddWithValue("@DaysBack", daysBack);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
            results.Add(MapBackupHistory(reader));

        return results;
    }

    public async Task<IEnumerable<RecoveryValidationDto>> GetRecoveryValidationAsync(int daysBack = 30)
    {
        List<RecoveryValidationDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Report_RecoveryValidation", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@DaysBack", daysBack);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new RecoveryValidationDto
            {
                ValidationId = Convert.ToInt32(reader["ValidationId"]),
                DatabaseName = reader["DatabaseName"].ToString()!,
                ValidationType = reader["ValidationType"].ToString()!,
                BackupPath = GetNullableString(reader, "BackupPath"),
                TargetPointInTime = GetNullableDateTime(reader, "TargetPointInTime"),
                StartTime = Convert.ToDateTime(reader["StartTime"]),
                EndTime = GetNullableDateTime(reader, "EndTime"),
                Status = reader["Status"].ToString()!,
                Details = GetNullableString(reader, "Details"),
                ErrorMessage = GetNullableString(reader, "ErrorMessage")
            });
        }

        return results;
    }

    public async Task<SecurityAuditSummaryDto> GetSecurityAuditSummaryAsync(int hoursBack = 24)
    {
        SecurityAuditSummaryDto summary = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Report_SecurityAuditSummary", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@HoursBack", hoursBack);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        List<SecurityAccessSummaryDto> access = new();
        while (await reader.ReadAsync())
        {
            access.Add(new SecurityAccessSummaryDto
            {
                LoginName = GetNullableString(reader, "LoginName"),
                SessionSightings = Convert.ToInt32(reader["SessionSightings"]),
                DistinctHosts = Convert.ToInt32(reader["DistinctHosts"]),
                DistinctPrograms = Convert.ToInt32(reader["DistinctPrograms"]),
                FirstSeen = GetNullableDateTime(reader, "FirstSeen"),
                LastSeen = GetNullableDateTime(reader, "LastSeen")
            });
        }
        summary.AccessByLogin = access;

        await reader.NextResultAsync();
        List<SecurityRoleMemberCountDto> roles = new();
        while (await reader.ReadAsync())
        {
            roles.Add(new SecurityRoleMemberCountDto
            {
                RoleName = reader["RoleName"].ToString()!,
                MemberCount = Convert.ToInt32(reader["MemberCount"])
            });
        }
        summary.RoleMembers = roles;

        await reader.NextResultAsync();
        List<MaskedColumnDto> masks = new();
        while (await reader.ReadAsync())
        {
            masks.Add(new MaskedColumnDto
            {
                SchemaName = reader["SchemaName"].ToString()!,
                TableName = reader["TableName"].ToString()!,
                ColumnName = reader["ColumnName"].ToString()!,
                IsMasked = Convert.ToBoolean(reader["IsMasked"])
            });
        }
        summary.MaskedColumns = masks;

        return summary;
    }

    public async Task<DatabaseHealthStatusDto> GetDatabaseHealthStatusAsync()
    {
        DatabaseHealthStatusDto dto = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Report_DatabaseHealthStatus", connection) { CommandType = CommandType.StoredProcedure };
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            dto.DatabaseName = reader["DatabaseName"].ToString()!;
            dto.RecoveryModel = reader["RecoveryModel"].ToString()!;
            dto.StateDesc = reader["StateDesc"].ToString()!;
            dto.TotalSizeMB = Convert.ToDecimal(reader["TotalSizeMB"]);
            dto.ActiveUserSessions = Convert.ToInt32(reader["ActiveUserSessions"]);
            dto.FailedBackupsLast24h = Convert.ToInt32(reader["FailedBackupsLast24h"]);
            dto.OpenCriticalAlerts = Convert.ToInt32(reader["OpenCriticalAlerts"]);
            dto.CapturedAtUtc = Convert.ToDateTime(reader["CapturedAtUtc"]);
        }

        return dto;
    }

    public async Task<IEnumerable<JobExecutionHistoryDto>> GetJobExecutionHistoryAsync(int hoursBack = 72)
    {
        List<JobExecutionHistoryDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Report_JobExecutionHistory", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@HoursBack", hoursBack);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new JobExecutionHistoryDto
            {
                JobName = reader["JobName"].ToString()!,
                StepId = Convert.ToInt32(reader["StepId"]),
                StepName = reader["StepName"].ToString()!,
                RunDateTime = Convert.ToDateTime(reader["RunDateTime"]),
                StatusName = reader["StatusName"].ToString()!,
                RunDuration = Convert.ToInt32(reader["RunDuration"]),
                MessageText = GetNullableString(reader, "MessageText")
            });
        }

        return results;
    }

    public async Task<IEnumerable<OpsAlertDto>> GetOpsAlertsAsync(int daysBack = 7, bool unacknowledgedOnly = false)
    {
        List<OpsAlertDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_Report_OpsAlerts", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@DaysBack", daysBack);
        command.Parameters.AddWithValue("@UnacknowledgedOnly", unacknowledgedOnly);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new OpsAlertDto
            {
                AlertId = Convert.ToInt32(reader["AlertId"]),
                AlertType = reader["AlertType"].ToString()!,
                Severity = reader["Severity"].ToString()!,
                MessageText = reader["MessageText"].ToString()!,
                MetricValue = reader["MetricValue"] == DBNull.Value ? null : Convert.ToDecimal(reader["MetricValue"]),
                ThresholdValue = reader["ThresholdValue"] == DBNull.Value ? null : Convert.ToDecimal(reader["ThresholdValue"]),
                CapturedAt = Convert.ToDateTime(reader["CapturedAt"]),
                IsAcknowledged = Convert.ToBoolean(reader["IsAcknowledged"])
            });
        }

        return results;
    }

    public async Task<PitRestoreScriptDto> GeneratePointInTimeRestoreScriptAsync(DateTime pointInTimeUtc, string? targetDatabase = null)
    {
        PitRestoreScriptDto dto = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("sp_DR_GeneratePointInTimeRestoreScript", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@PointInTimeUtc", pointInTimeUtc);
        if (!string.IsNullOrWhiteSpace(targetDatabase))
            command.Parameters.AddWithValue("@TargetDatabase", targetDatabase);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            dto.RestoreScript = reader["RestoreScript"].ToString()!;
            dto.FullBackupPath = GetNullableString(reader, "FullBackupPath");
            dto.DifferentialBackupPath = GetNullableString(reader, "DifferentialBackupPath");
            dto.PointInTimeUtc = Convert.ToDateTime(reader["PointInTimeUtc"]);
            dto.TargetDatabase = reader["TargetDatabase"].ToString()!;
        }

        return dto;
    }

    public async Task<byte[]> ExportBackupHistoryExcelAsync(int daysBack = 30)
    {
        var data = (await GetBackupHistoryAsync(daysBack)).ToList();
        return BuildExcel("Backup History", new[]
        {
            "BackupRunId", "Database", "Type", "Path", "Start", "End", "Status", "SizeMB", "Verified", "DurationSec", "Error"
        }, data.Select(x => new object?[]
        {
            x.BackupRunId, x.DatabaseName, x.BackupType, x.BackupPath, x.StartTime, x.EndTime,
            x.Status, x.BackupSizeMB, x.Verified, x.DurationSeconds, x.ErrorMessage
        }));
    }

    public async Task<byte[]> ExportRecoveryValidationExcelAsync(int daysBack = 30)
    {
        var data = (await GetRecoveryValidationAsync(daysBack)).ToList();
        return BuildExcel("Recovery Validation", new[]
        {
            "ValidationId", "Database", "Type", "BackupPath", "PIT", "Start", "End", "Status", "Details", "Error"
        }, data.Select(x => new object?[]
        {
            x.ValidationId, x.DatabaseName, x.ValidationType, x.BackupPath, x.TargetPointInTime,
            x.StartTime, x.EndTime, x.Status, x.Details, x.ErrorMessage
        }));
    }

    public async Task<byte[]> ExportSecurityAuditExcelAsync(int hoursBack = 24)
    {
        var summary = await GetSecurityAuditSummaryAsync(hoursBack);
        using XLWorkbook workbook = new();

        var access = workbook.Worksheets.Add("Access Summary");
        WriteSheet(access, new[] { "Login", "Sightings", "Hosts", "Programs", "FirstSeen", "LastSeen" },
            summary.AccessByLogin.Select(x => new object?[] { x.LoginName, x.SessionSightings, x.DistinctHosts, x.DistinctPrograms, x.FirstSeen, x.LastSeen }));

        var roles = workbook.Worksheets.Add("Roles");
        WriteSheet(roles, new[] { "Role", "Members" },
            summary.RoleMembers.Select(x => new object?[] { x.RoleName, x.MemberCount }));

        var masks = workbook.Worksheets.Add("Masked Columns");
        WriteSheet(masks, new[] { "Schema", "Table", "Column", "IsMasked" },
            summary.MaskedColumns.Select(x => new object?[] { x.SchemaName, x.TableName, x.ColumnName, x.IsMasked }));

        using MemoryStream stream = new();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }

    public async Task<byte[]> ExportDatabaseHealthExcelAsync()
    {
        var health = await GetDatabaseHealthStatusAsync();
        return BuildExcel("Database Health", new[]
        {
            "Database", "RecoveryModel", "State", "TotalSizeMB", "ActiveSessions", "FailedBackups24h", "CriticalAlerts", "CapturedAt"
        }, new[]
        {
            new object?[]
            {
                health.DatabaseName, health.RecoveryModel, health.StateDesc, health.TotalSizeMB,
                health.ActiveUserSessions, health.FailedBackupsLast24h, health.OpenCriticalAlerts, health.CapturedAtUtc
            }
        });
    }

    public async Task<byte[]> ExportJobExecutionExcelAsync(int hoursBack = 72)
    {
        var data = (await GetJobExecutionHistoryAsync(hoursBack)).ToList();
        return BuildExcel("Job Execution", new[]
        {
            "Job", "StepId", "Step", "RunDateTime", "Status", "Duration", "Message"
        }, data.Select(x => new object?[]
        {
            x.JobName, x.StepId, x.StepName, x.RunDateTime, x.StatusName, x.RunDuration, x.MessageText
        }));
    }

    public async Task<string> ExportBackupHistoryCsvAsync(int daysBack = 30)
    {
        var data = await GetBackupHistoryAsync(daysBack);
        StringBuilder csv = new();
        csv.AppendLine("BackupRunId,DatabaseName,BackupType,BackupPath,StartTime,EndTime,Status,BackupSizeMB,Verified,DurationSeconds,ErrorMessage");
        foreach (var x in data)
            csv.AppendLine($"{x.BackupRunId},{Escape(x.DatabaseName)},{Escape(x.BackupType)},{Escape(x.BackupPath)},{x.StartTime:o},{x.EndTime:o},{Escape(x.Status)},{x.BackupSizeMB},{x.Verified},{x.DurationSeconds},{Escape(x.ErrorMessage)}");
        return csv.ToString();
    }

    public async Task<string> ExportRecoveryValidationCsvAsync(int daysBack = 30)
    {
        var data = await GetRecoveryValidationAsync(daysBack);
        StringBuilder csv = new();
        csv.AppendLine("ValidationId,DatabaseName,ValidationType,BackupPath,TargetPointInTime,StartTime,EndTime,Status,Details,ErrorMessage");
        foreach (var x in data)
            csv.AppendLine($"{x.ValidationId},{Escape(x.DatabaseName)},{Escape(x.ValidationType)},{Escape(x.BackupPath)},{x.TargetPointInTime:o},{x.StartTime:o},{x.EndTime:o},{Escape(x.Status)},{Escape(x.Details)},{Escape(x.ErrorMessage)}");
        return csv.ToString();
    }

    public async Task<string> ExportSecurityAuditCsvAsync(int hoursBack = 24)
    {
        var summary = await GetSecurityAuditSummaryAsync(hoursBack);
        StringBuilder csv = new();
        csv.AppendLine("LoginName,SessionSightings,DistinctHosts,DistinctPrograms,FirstSeen,LastSeen");
        foreach (var x in summary.AccessByLogin)
            csv.AppendLine($"{Escape(x.LoginName)},{x.SessionSightings},{x.DistinctHosts},{x.DistinctPrograms},{x.FirstSeen:o},{x.LastSeen:o}");
        return csv.ToString();
    }

    public async Task<string> ExportDatabaseHealthCsvAsync()
    {
        var h = await GetDatabaseHealthStatusAsync();
        return "DatabaseName,RecoveryModel,StateDesc,TotalSizeMB,ActiveUserSessions,FailedBackupsLast24h,OpenCriticalAlerts,CapturedAtUtc\n"
             + $"{Escape(h.DatabaseName)},{Escape(h.RecoveryModel)},{Escape(h.StateDesc)},{h.TotalSizeMB},{h.ActiveUserSessions},{h.FailedBackupsLast24h},{h.OpenCriticalAlerts},{h.CapturedAtUtc:o}\n";
    }

    public async Task<string> ExportJobExecutionCsvAsync(int hoursBack = 72)
    {
        var data = await GetJobExecutionHistoryAsync(hoursBack);
        StringBuilder csv = new();
        csv.AppendLine("JobName,StepId,StepName,RunDateTime,StatusName,RunDuration,MessageText");
        foreach (var x in data)
            csv.AppendLine($"{Escape(x.JobName)},{x.StepId},{Escape(x.StepName)},{x.RunDateTime:o},{Escape(x.StatusName)},{x.RunDuration},{Escape(x.MessageText)}");
        return csv.ToString();
    }

    private static BackupHistoryDto MapBackupHistory(SqlDataReader reader) => new()
    {
        BackupRunId = Convert.ToInt32(reader["BackupRunId"]),
        DatabaseName = reader["DatabaseName"].ToString()!,
        BackupType = reader["BackupType"].ToString()!,
        BackupPath = reader["BackupPath"].ToString()!,
        StartTime = Convert.ToDateTime(reader["StartTime"]),
        EndTime = GetNullableDateTime(reader, "EndTime"),
        Status = reader["Status"].ToString()!,
        BackupSizeMB = reader["BackupSizeMB"] == DBNull.Value ? null : Convert.ToDecimal(reader["BackupSizeMB"]),
        Verified = Convert.ToBoolean(reader["Verified"]),
        DurationSeconds = GetNullableInt32(reader, "DurationSeconds"),
        ErrorMessage = GetNullableString(reader, "ErrorMessage")
    };

    private static byte[] BuildExcel(string sheetName, string[] headers, IEnumerable<object?[]> rows)
    {
        using XLWorkbook workbook = new();
        var sheet = workbook.Worksheets.Add(sheetName);
        WriteSheet(sheet, headers, rows);
        using MemoryStream stream = new();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }

    private static void WriteSheet(IXLWorksheet sheet, string[] headers, IEnumerable<object?[]> rows)
    {
        for (int c = 0; c < headers.Length; c++)
            sheet.Cell(1, c + 1).Value = headers[c];
        sheet.Row(1).Style.Font.Bold = true;

        int r = 2;
        foreach (var row in rows)
        {
            for (int c = 0; c < row.Length; c++)
            {
                object? value = row[c];
                if (value is null) continue;
                if (value is DateTime dt) sheet.Cell(r, c + 1).Value = dt;
                else if (value is bool b) sheet.Cell(r, c + 1).Value = b;
                else if (value is int i) sheet.Cell(r, c + 1).Value = i;
                else if (value is long l) sheet.Cell(r, c + 1).Value = l;
                else if (value is decimal d) sheet.Cell(r, c + 1).Value = d;
                else sheet.Cell(r, c + 1).Value = value.ToString();
            }
            r++;
        }
    }

    private static string Escape(string? value)
    {
        if (string.IsNullOrEmpty(value)) return string.Empty;
        if (value.Contains(',') || value.Contains('"') || value.Contains('\n'))
            return $"\"{value.Replace("\"", "\"\"")}\"";
        return value;
    }

    private static string? GetNullableString(SqlDataReader reader, string name)
        => reader[name] == DBNull.Value ? null : reader[name].ToString();

    private static DateTime? GetNullableDateTime(SqlDataReader reader, string name)
        => reader[name] == DBNull.Value ? null : Convert.ToDateTime(reader[name]);

    private static int? GetNullableInt32(SqlDataReader reader, string name)
        => reader[name] == DBNull.Value ? null : Convert.ToInt32(reader[name]);
}
