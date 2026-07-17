using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Text;

namespace EmployeeLeaveManagment.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public class BackupSecurityController : ControllerBase
{
    private readonly IBackupSecurityService _service;

    public BackupSecurityController(IBackupSecurityService service)
    {
        _service = service;
    }

    [HttpGet("backup-status")]
    public async Task<IActionResult> GetBackupStatus([FromQuery] string databaseName = "EmployeeLeaveDb")
        => Ok(await _service.GetBackupStatusAsync(databaseName));

    [HttpGet("reports/backup-history")]
    public async Task<IActionResult> GetBackupHistory([FromQuery] int daysBack = 30, [FromQuery] string databaseName = "EmployeeLeaveDb")
    {
        if (daysBack < 1 || daysBack > 365)
            return BadRequest(new { Message = "daysBack must be between 1 and 365." });
        return Ok(await _service.GetBackupHistoryAsync(daysBack, databaseName));
    }

    [HttpGet("reports/recovery-validation")]
    public async Task<IActionResult> GetRecoveryValidation([FromQuery] int daysBack = 30)
        => Ok(await _service.GetRecoveryValidationAsync(daysBack));

    [HttpGet("reports/security-audit")]
    public async Task<IActionResult> GetSecurityAudit([FromQuery] int hoursBack = 24)
        => Ok(await _service.GetSecurityAuditSummaryAsync(hoursBack));

    [HttpGet("reports/database-health")]
    public async Task<IActionResult> GetDatabaseHealth()
        => Ok(await _service.GetDatabaseHealthStatusAsync());

    [HttpGet("reports/job-execution")]
    public async Task<IActionResult> GetJobExecution([FromQuery] int hoursBack = 72)
        => Ok(await _service.GetJobExecutionHistoryAsync(hoursBack));

    [HttpGet("alerts")]
    public async Task<IActionResult> GetAlerts([FromQuery] int daysBack = 7, [FromQuery] bool unacknowledgedOnly = false)
        => Ok(await _service.GetOpsAlertsAsync(daysBack, unacknowledgedOnly));

    [HttpPost("dr/point-in-time-script")]
    public async Task<IActionResult> GeneratePitScript([FromBody] BackupSecurityFilterDto? filter)
    {
        if (filter?.PointInTimeUtc is null)
            return BadRequest(new { Message = "PointInTimeUtc is required." });

        var result = await _service.GeneratePointInTimeRestoreScriptAsync(filter.PointInTimeUtc.Value);
        return Ok(result);
    }

    [HttpPost("export/backup-history-excel")]
    public async Task<IActionResult> ExportBackupHistoryExcel([FromBody] BackupSecurityFilterDto? filter)
    {
        var bytes = await _service.ExportBackupHistoryExcelAsync(filter?.DaysBack ?? 30);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "BackupHistory.xlsx");
    }

    [HttpPost("export/recovery-validation-excel")]
    public async Task<IActionResult> ExportRecoveryValidationExcel([FromBody] BackupSecurityFilterDto? filter)
    {
        var bytes = await _service.ExportRecoveryValidationExcelAsync(filter?.DaysBack ?? 30);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "RecoveryValidation.xlsx");
    }

    [HttpPost("export/security-audit-excel")]
    public async Task<IActionResult> ExportSecurityAuditExcel([FromBody] BackupSecurityFilterDto? filter)
    {
        var bytes = await _service.ExportSecurityAuditExcelAsync(filter?.HoursBack ?? 24);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "SecurityAudit.xlsx");
    }

    [HttpPost("export/database-health-excel")]
    public async Task<IActionResult> ExportDatabaseHealthExcel()
    {
        var bytes = await _service.ExportDatabaseHealthExcelAsync();
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "DatabaseHealth.xlsx");
    }

    [HttpPost("export/job-execution-excel")]
    public async Task<IActionResult> ExportJobExecutionExcel([FromBody] BackupSecurityFilterDto? filter)
    {
        var bytes = await _service.ExportJobExecutionExcelAsync(filter?.HoursBack ?? 72);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "JobExecution.xlsx");
    }

    [HttpPost("export/backup-history-csv")]
    public async Task<IActionResult> ExportBackupHistoryCsv([FromBody] BackupSecurityFilterDto? filter)
    {
        var csv = await _service.ExportBackupHistoryCsvAsync(filter?.DaysBack ?? 30);
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "BackupHistory.csv");
    }

    [HttpPost("export/recovery-validation-csv")]
    public async Task<IActionResult> ExportRecoveryValidationCsv([FromBody] BackupSecurityFilterDto? filter)
    {
        var csv = await _service.ExportRecoveryValidationCsvAsync(filter?.DaysBack ?? 30);
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "RecoveryValidation.csv");
    }

    [HttpPost("export/security-audit-csv")]
    public async Task<IActionResult> ExportSecurityAuditCsv([FromBody] BackupSecurityFilterDto? filter)
    {
        var csv = await _service.ExportSecurityAuditCsvAsync(filter?.HoursBack ?? 24);
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "SecurityAudit.csv");
    }

    [HttpPost("export/database-health-csv")]
    public async Task<IActionResult> ExportDatabaseHealthCsv()
    {
        var csv = await _service.ExportDatabaseHealthCsvAsync();
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "DatabaseHealth.csv");
    }

    [HttpPost("export/job-execution-csv")]
    public async Task<IActionResult> ExportJobExecutionCsv([FromBody] BackupSecurityFilterDto? filter)
    {
        var csv = await _service.ExportJobExecutionCsvAsync(filter?.HoursBack ?? 72);
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "JobExecution.csv");
    }
}
