using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Text;

namespace EmployeeLeaveManagment.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public class AuditIntegrityController : ControllerBase
{
    private readonly IAuditIntegrityService _service;

    public AuditIntegrityController(IAuditIntegrityService service)
    {
        _service = service;
    }

    [HttpPost("run-checks")]
    public async Task<IActionResult> RunChecks([FromQuery] int? balanceYear = null)
        => Ok(await _service.RunAllIntegrityChecksAsync(balanceYear));

    [HttpGet("compliance-status")]
    public async Task<IActionResult> GetComplianceStatus()
        => Ok(await _service.GetComplianceStatusAsync());

    [HttpGet("reports/integrity-violations")]
    public async Task<IActionResult> GetIntegrityViolations(
        [FromQuery] int daysBack = 30,
        [FromQuery] bool unresolvedOnly = false,
        [FromQuery] string? severity = null)
    {
        if (daysBack < 1 || daysBack > 365)
            return BadRequest(new { Message = "daysBack must be between 1 and 365." });
        return Ok(await _service.GetIntegrityViolationsAsync(daysBack, unresolvedOnly, severity));
    }

    [HttpGet("reports/audit-summary")]
    public async Task<IActionResult> GetAuditSummary([FromQuery] int daysBack = 30)
        => Ok(await _service.GetAuditSummaryAsync(daysBack));

    [HttpGet("reports/data-quality")]
    public async Task<IActionResult> GetDataQuality()
        => Ok(await _service.GetDataQualityStatusAsync());

    [HttpGet("reports/user-activity")]
    public async Task<IActionResult> GetUserActivity([FromQuery] int daysBack = 30)
        => Ok(await _service.GetUserActivitySummaryAsync(daysBack));

    [HttpGet("monitor/failed-validations")]
    public async Task<IActionResult> GetFailedValidations([FromQuery] int hoursBack = 48)
        => Ok(await _service.GetFailedValidationChecksAsync(hoursBack));

    [HttpGet("monitor/exceptions")]
    public async Task<IActionResult> GetExceptions([FromQuery] int hoursBack = 48)
        => Ok(await _service.GetDatabaseExceptionsAsync(hoursBack));

    [HttpGet("monitor/scheduled-jobs")]
    public async Task<IActionResult> GetScheduledJobs([FromQuery] int hoursBack = 72)
        => Ok(await _service.GetScheduledAuditJobHistoryAsync(hoursBack));

    [HttpPost("violations/{violationId:long}/resolve")]
    public async Task<IActionResult> ResolveViolation(long violationId, [FromBody] ResolveViolationRequestDto request)
    {
        if (string.IsNullOrWhiteSpace(request.ResolvedBy))
            return BadRequest(new { Message = "ResolvedBy is required." });

        try
        {
            var result = await _service.ResolveViolationAsync(violationId, request);
            return result is null ? NotFound() : Ok(result);
        }
        catch (Microsoft.Data.SqlClient.SqlException ex) when (ex.Number == 50010)
        {
            return NotFound(new { Message = ex.Message });
        }
    }

    [HttpPost("user-activity")]
    public async Task<IActionResult> LogUserActivity([FromBody] LogUserActivityRequestDto request)
    {
        if (string.IsNullOrWhiteSpace(request.ActivityType))
            return BadRequest(new { Message = "ActivityType is required." });

        var id = await _service.LogUserActivityAsync(request);
        return Ok(new { ActivityId = id });
    }

    [HttpPost("export/integrity-violations-excel")]
    public async Task<IActionResult> ExportIntegrityViolationsExcel([FromBody] AuditIntegrityFilterDto? filter)
    {
        var bytes = await _service.ExportIntegrityViolationsExcelAsync(filter?.DaysBack ?? 30, filter?.UnresolvedOnly ?? false);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "IntegrityViolations.xlsx");
    }

    [HttpPost("export/audit-summary-excel")]
    public async Task<IActionResult> ExportAuditSummaryExcel([FromBody] AuditIntegrityFilterDto? filter)
    {
        var bytes = await _service.ExportAuditSummaryExcelAsync(filter?.DaysBack ?? 30);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "AuditSummary.xlsx");
    }

    [HttpPost("export/data-quality-excel")]
    public async Task<IActionResult> ExportDataQualityExcel()
    {
        var bytes = await _service.ExportDataQualityExcelAsync();
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "DataQualityStatus.xlsx");
    }

    [HttpPost("export/user-activity-excel")]
    public async Task<IActionResult> ExportUserActivityExcel([FromBody] AuditIntegrityFilterDto? filter)
    {
        var bytes = await _service.ExportUserActivityExcelAsync(filter?.DaysBack ?? 30);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "UserActivitySummary.xlsx");
    }

    [HttpPost("export/compliance-status-excel")]
    public async Task<IActionResult> ExportComplianceStatusExcel()
    {
        var bytes = await _service.ExportComplianceStatusExcelAsync();
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "ComplianceStatus.xlsx");
    }

    [HttpPost("export/integrity-violations-csv")]
    public async Task<IActionResult> ExportIntegrityViolationsCsv([FromBody] AuditIntegrityFilterDto? filter)
    {
        var csv = await _service.ExportIntegrityViolationsCsvAsync(filter?.DaysBack ?? 30, filter?.UnresolvedOnly ?? false);
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "IntegrityViolations.csv");
    }

    [HttpPost("export/audit-summary-csv")]
    public async Task<IActionResult> ExportAuditSummaryCsv([FromBody] AuditIntegrityFilterDto? filter)
    {
        var csv = await _service.ExportAuditSummaryCsvAsync(filter?.DaysBack ?? 30);
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "AuditSummary.csv");
    }

    [HttpPost("export/data-quality-csv")]
    public async Task<IActionResult> ExportDataQualityCsv()
    {
        var csv = await _service.ExportDataQualityCsvAsync();
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "DataQualityStatus.csv");
    }

    [HttpPost("export/user-activity-csv")]
    public async Task<IActionResult> ExportUserActivityCsv([FromBody] AuditIntegrityFilterDto? filter)
    {
        var csv = await _service.ExportUserActivityCsvAsync(filter?.DaysBack ?? 30);
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "UserActivitySummary.csv");
    }

    [HttpPost("export/compliance-status-csv")]
    public async Task<IActionResult> ExportComplianceStatusCsv()
    {
        var csv = await _service.ExportComplianceStatusCsvAsync();
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "ComplianceStatus.csv");
    }
}
