using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Text;

namespace EmployeeLeaveManagment.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public class MigrationFrameworkController : ControllerBase
{
    private readonly IMigrationFrameworkService _service;

    public MigrationFrameworkController(IMigrationFrameworkService service)
    {
        _service = service;
    }

    [HttpGet("migrations")]
    public async Task<IActionResult> GetMigrations([FromQuery] string? status = null, [FromQuery] int topN = 100)
        => Ok(await _service.GetMigrationHistoryAsync(status, topN));

    [HttpPost("migrations/apply")]
    public async Task<IActionResult> ApplyMigration([FromBody] ApplyMigrationRequestDto request)
    {
        if (string.IsNullOrWhiteSpace(request.VersionNumber) || string.IsNullOrWhiteSpace(request.UpSql))
            return BadRequest(new { Message = "VersionNumber and UpSql are required." });
        try { return Ok(await _service.ApplyMigrationAsync(request)); }
        catch (Microsoft.Data.SqlClient.SqlException ex) when (ex.Number is >= 51001 and <= 51006)
        { return BadRequest(new { Message = ex.Message }); }
    }

    [HttpPost("migrations/rollback")]
    public async Task<IActionResult> Rollback([FromQuery] string? versionNumber = null)
    {
        try { return Ok(await _service.RollbackMigrationAsync(versionNumber)); }
        catch (Microsoft.Data.SqlClient.SqlException ex) when (ex.Number is >= 51001 and <= 51006)
        { return BadRequest(new { Message = ex.Message }); }
    }

    [HttpPost("migrations/apply-sample")]
    public async Task<IActionResult> ApplySample()
    {
        try { return Ok(await _service.ApplySampleMigrationAsync()); }
        catch (Microsoft.Data.SqlClient.SqlException ex) when (ex.Number == 51001)
        { return Conflict(new { Message = ex.Message }); }
    }

    [HttpGet("metadata/modules")]
    public async Task<IActionResult> GetModules([FromQuery] bool activeOnly = true)
        => Ok(await _service.GetModulesAsync(activeOnly));

    [HttpGet("metadata/config-categories")]
    public async Task<IActionResult> GetConfigCategories([FromQuery] string? moduleCode = null, [FromQuery] bool activeOnly = true)
        => Ok(await _service.GetConfigCategoriesAsync(moduleCode, activeOnly));

    [HttpGet("metadata/lookups/{categoryCode}")]
    public async Task<IActionResult> GetLookups(string categoryCode, [FromQuery] bool activeOnly = true)
        => Ok(await _service.GetLookupValuesAsync(categoryCode, activeOnly));

    [HttpGet("metadata/audit-categories")]
    public async Task<IActionResult> GetAuditCategories([FromQuery] bool activeOnly = true)
        => Ok(await _service.GetAuditCategoriesAsync(activeOnly));

    [HttpPost("metadata/lookups")]
    public async Task<IActionResult> UpsertLookup([FromBody] UpsertLookupRequestDto request)
        => Ok(await _service.UpsertLookupAsync(request));

    [HttpPost("metadata/refresh")]
    public async Task<IActionResult> RefreshMetadata()
        => Ok(await _service.RefreshMetadataAsync());

    [HttpGet("reports/metadata-usage")]
    public async Task<IActionResult> GetMetadataUsage()
        => Ok(await _service.GetMetadataUsageAsync());

    [HttpPost("validation/run")]
    public async Task<IActionResult> RunValidation([FromQuery] int? balanceYear = null)
        => Ok(await _service.RunValidationAsync(balanceYear));

    [HttpGet("reports/validation-summary")]
    public async Task<IActionResult> GetValidationSummary([FromQuery] int daysBack = 30)
        => Ok(await _service.GetValidationSummaryAsync(daysBack));

    [HttpGet("reports/validation-issues")]
    public async Task<IActionResult> GetValidationIssues([FromQuery] int daysBack = 30, [FromQuery] bool unresolvedOnly = false, [FromQuery] string? checkCode = null)
        => Ok(await _service.GetValidationIssuesAsync(daysBack, unresolvedOnly, checkCode));

    [HttpGet("dashboard/data-quality")]
    public async Task<IActionResult> GetDataQualityDashboard()
        => Ok(await _service.GetDataQualityDashboardAsync());

    [HttpPost("validation/{validationId:long}/resolve")]
    public async Task<IActionResult> ResolveIssue(long validationId, [FromBody] ResolveValidationRequestDto request)
    {
        if (string.IsNullOrWhiteSpace(request.ResolvedBy))
            return BadRequest(new { Message = "ResolvedBy is required." });
        try
        {
            var result = await _service.ResolveValidationIssueAsync(validationId, request.ResolvedBy);
            return result is null ? NotFound() : Ok(result);
        }
        catch (Microsoft.Data.SqlClient.SqlException ex) when (ex.Number == 51010)
        { return NotFound(new { Message = ex.Message }); }
    }

    [HttpPost("export/migration-history-excel")]
    public async Task<IActionResult> ExportMigrationExcel([FromBody] MigrationFrameworkFilterDto? filter)
        => File(await _service.ExportMigrationHistoryExcelAsync(filter?.TopN ?? 100),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "MigrationHistory.xlsx");

    [HttpPost("export/validation-summary-excel")]
    public async Task<IActionResult> ExportValSummaryExcel([FromBody] MigrationFrameworkFilterDto? filter)
        => File(await _service.ExportValidationSummaryExcelAsync(filter?.DaysBack ?? 30),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "ValidationSummary.xlsx");

    [HttpPost("export/validation-issues-excel")]
    public async Task<IActionResult> ExportValIssuesExcel([FromBody] MigrationFrameworkFilterDto? filter)
        => File(await _service.ExportValidationIssuesExcelAsync(filter?.DaysBack ?? 30),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "ValidationIssues.xlsx");

    [HttpPost("export/data-quality-excel")]
    public async Task<IActionResult> ExportDqExcel()
        => File(await _service.ExportDataQualityExcelAsync(),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "DataQualityDashboard.xlsx");

    [HttpPost("export/metadata-usage-excel")]
    public async Task<IActionResult> ExportMetaExcel()
        => File(await _service.ExportMetadataUsageExcelAsync(),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "MetadataUsage.xlsx");

    [HttpPost("export/migration-history-csv")]
    public async Task<IActionResult> ExportMigrationCsv([FromBody] MigrationFrameworkFilterDto? filter)
        => File(Encoding.UTF8.GetBytes(await _service.ExportMigrationHistoryCsvAsync(filter?.TopN ?? 100)), "text/csv", "MigrationHistory.csv");

    [HttpPost("export/validation-summary-csv")]
    public async Task<IActionResult> ExportValSummaryCsv([FromBody] MigrationFrameworkFilterDto? filter)
        => File(Encoding.UTF8.GetBytes(await _service.ExportValidationSummaryCsvAsync(filter?.DaysBack ?? 30)), "text/csv", "ValidationSummary.csv");

    [HttpPost("export/validation-issues-csv")]
    public async Task<IActionResult> ExportValIssuesCsv([FromBody] MigrationFrameworkFilterDto? filter)
        => File(Encoding.UTF8.GetBytes(await _service.ExportValidationIssuesCsvAsync(filter?.DaysBack ?? 30)), "text/csv", "ValidationIssues.csv");

    [HttpPost("export/data-quality-csv")]
    public async Task<IActionResult> ExportDqCsv()
        => File(Encoding.UTF8.GetBytes(await _service.ExportDataQualityCsvAsync()), "text/csv", "DataQualityDashboard.csv");

    [HttpPost("export/metadata-usage-csv")]
    public async Task<IActionResult> ExportMetaCsv()
        => File(Encoding.UTF8.GetBytes(await _service.ExportMetadataUsageCsvAsync()), "text/csv", "MetadataUsage.csv");
}
