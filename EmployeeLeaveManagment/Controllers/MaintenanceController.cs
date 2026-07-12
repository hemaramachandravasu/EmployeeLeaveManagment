using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Text;

namespace EmployeeLeaveManagment.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public class MaintenanceController : ControllerBase
{
    private readonly IMaintenanceService _maintenanceService;

    public MaintenanceController(IMaintenanceService maintenanceService)
    {
        _maintenanceService = maintenanceService;
    }

    /// <summary>Database health dashboard: size, connections, fragmentation, archive stats, maintenance history.</summary>
    [HttpGet("health")]
    public async Task<IActionResult> GetHealthDashboard()
    {
        var result = await _maintenanceService.GetHealthDashboardAsync();
        return Ok(result);
    }

    [HttpGet("database-size")]
    public async Task<IActionResult> GetDatabaseSize()
    {
        var result = await _maintenanceService.GetDatabaseSizeAsync();
        return Ok(result);
    }

    [HttpGet("retention")]
    public async Task<IActionResult> GetRetentionConfig()
    {
        var result = await _maintenanceService.GetRetentionConfigAsync();
        return Ok(result);
    }

    [HttpPut("retention")]
    public async Task<IActionResult> UpdateRetention([FromBody] UpdateRetentionRequestDto request)
    {
        if (string.IsNullOrWhiteSpace(request.EntityName))
            return BadRequest(new { Message = "EntityName is required." });
        if (request.RetentionDays < 30)
            return BadRequest(new { Message = "RetentionDays must be at least 30." });

        var result = await _maintenanceService.UpdateRetentionAsync(request);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpGet("reports/monthly-growth")]
    public async Task<IActionResult> GetMonthlyGrowth([FromQuery] int monthsBack = 12)
    {
        if (monthsBack < 1 || monthsBack > 60)
            return BadRequest(new { Message = "monthsBack must be between 1 and 60." });

        var result = await _maintenanceService.GetMonthlyGrowthAsync(monthsBack);
        return Ok(result);
    }

    [HttpGet("reports/index-health")]
    public async Task<IActionResult> GetIndexHealth([FromQuery] int minPageCount = 50)
    {
        var result = await _maintenanceService.GetIndexHealthAsync(minPageCount);
        return Ok(result);
    }

    [HttpGet("reports/query-performance")]
    public async Task<IActionResult> GetQueryPerformance([FromQuery] int topN = 25)
    {
        if (topN < 1 || topN > 100)
            return BadRequest(new { Message = "topN must be between 1 and 100." });

        var result = await _maintenanceService.GetQueryPerformanceAsync(topN);
        return Ok(result);
    }

    [HttpGet("reports/archive-summary")]
    public async Task<IActionResult> GetArchiveSummary([FromQuery] int daysBack = 90)
    {
        var result = await _maintenanceService.GetArchiveSummaryAsync(daysBack);
        return Ok(result);
    }

    [HttpGet("reports/maintenance-execution")]
    public async Task<IActionResult> GetMaintenanceExecution([FromQuery] int daysBack = 90)
    {
        var result = await _maintenanceService.GetMaintenanceExecutionAsync(daysBack);
        return Ok(result);
    }

    [HttpPost("export/monthly-growth-excel")]
    public async Task<IActionResult> ExportMonthlyGrowthExcel([FromBody] MaintenanceFilterDto? filter)
    {
        var bytes = await _maintenanceService.ExportMonthlyGrowthExcelAsync(filter?.MonthsBack ?? 12);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "MonthlyDatabaseGrowth.xlsx");
    }

    [HttpPost("export/index-health-excel")]
    public async Task<IActionResult> ExportIndexHealthExcel([FromBody] MaintenanceFilterDto? filter)
    {
        var bytes = await _maintenanceService.ExportIndexHealthExcelAsync(filter?.MinPageCount ?? 50);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "IndexHealth.xlsx");
    }

    [HttpPost("export/query-performance-excel")]
    public async Task<IActionResult> ExportQueryPerformanceExcel([FromBody] MaintenanceFilterDto? filter)
    {
        var bytes = await _maintenanceService.ExportQueryPerformanceExcelAsync(filter?.TopN ?? 25);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "QueryPerformance.xlsx");
    }

    [HttpPost("export/archive-summary-excel")]
    public async Task<IActionResult> ExportArchiveSummaryExcel([FromBody] MaintenanceFilterDto? filter)
    {
        var bytes = await _maintenanceService.ExportArchiveSummaryExcelAsync(filter?.DaysBack ?? 90);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "ArchiveSummary.xlsx");
    }

    [HttpPost("export/maintenance-execution-excel")]
    public async Task<IActionResult> ExportMaintenanceExecutionExcel([FromBody] MaintenanceFilterDto? filter)
    {
        var bytes = await _maintenanceService.ExportMaintenanceExecutionExcelAsync(filter?.DaysBack ?? 90);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "MaintenanceExecution.xlsx");
    }

    [HttpPost("export/monthly-growth-csv")]
    public async Task<IActionResult> ExportMonthlyGrowthCsv([FromBody] MaintenanceFilterDto? filter)
    {
        var csv = await _maintenanceService.ExportMonthlyGrowthCsvAsync(filter?.MonthsBack ?? 12);
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "MonthlyDatabaseGrowth.csv");
    }

    [HttpPost("export/index-health-csv")]
    public async Task<IActionResult> ExportIndexHealthCsv([FromBody] MaintenanceFilterDto? filter)
    {
        var csv = await _maintenanceService.ExportIndexHealthCsvAsync(filter?.MinPageCount ?? 50);
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "IndexHealth.csv");
    }

    [HttpPost("export/query-performance-csv")]
    public async Task<IActionResult> ExportQueryPerformanceCsv([FromBody] MaintenanceFilterDto? filter)
    {
        var csv = await _maintenanceService.ExportQueryPerformanceCsvAsync(filter?.TopN ?? 25);
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "QueryPerformance.csv");
    }

    [HttpPost("export/archive-summary-csv")]
    public async Task<IActionResult> ExportArchiveSummaryCsv([FromBody] MaintenanceFilterDto? filter)
    {
        var csv = await _maintenanceService.ExportArchiveSummaryCsvAsync(filter?.DaysBack ?? 90);
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "ArchiveSummary.csv");
    }

    [HttpPost("export/maintenance-execution-csv")]
    public async Task<IActionResult> ExportMaintenanceExecutionCsv([FromBody] MaintenanceFilterDto? filter)
    {
        var csv = await _maintenanceService.ExportMaintenanceExecutionCsvAsync(filter?.DaysBack ?? 90);
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "MaintenanceExecution.csv");
    }
}
