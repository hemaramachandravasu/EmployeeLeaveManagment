using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Text;

namespace EmployeeLeaveManagment.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public class CapacityPerformanceController : ControllerBase
{
    private readonly ICapacityPerformanceService _service;

    public CapacityPerformanceController(ICapacityPerformanceService service)
    {
        _service = service;
    }

    [HttpGet("dashboard")]
    public async Task<IActionResult> GetDashboard()
        => Ok(await _service.GetDashboardAsync());

    [HttpGet("growth-trends")]
    public async Task<IActionResult> GetGrowthTrends([FromQuery] int daysBack = 90)
        => Ok(await _service.GetGrowthTrendsAsync(daysBack));

    [HttpGet("table-sizes")]
    public async Task<IActionResult> GetTableSizes()
        => Ok(await _service.GetTableSizesAsync());

    [HttpGet("storage")]
    public async Task<IActionResult> GetStorage()
        => Ok(await _service.GetStorageUtilizationAsync());

    [HttpGet("filegroups")]
    public async Task<IActionResult> GetFilegroups()
        => Ok(await _service.GetFilegroupUtilizationAsync());

    [HttpPost("forecast")]
    public async Task<IActionResult> Forecast([FromQuery] int lookbackDays = 90)
        => Ok(await _service.ForecastCapacityAsync(lookbackDays));

    [HttpGet("reports/capacity-summary")]
    public async Task<IActionResult> GetCapacitySummary()
        => Ok(await _service.GetCapacityPlanningSummaryAsync());

    [HttpGet("reports/sql-performance")]
    public async Task<IActionResult> GetSqlPerformance([FromQuery] int topN = 25)
        => Ok(await _service.GetSlowQueryStatisticsAsync(topN));

    [HttpGet("reports/query-trends")]
    public async Task<IActionResult> GetQueryTrends([FromQuery] int hoursBack = 24)
        => Ok(await _service.GetQueryExecutionTrendsAsync(hoursBack));

    [HttpGet("reports/index-utilization")]
    public async Task<IActionResult> GetIndexUtilization([FromQuery] bool includeUnusedOnly = false)
        => Ok(await _service.GetIndexUtilizationAsync(includeUnusedOnly));

    [HttpGet("reports/active-sessions")]
    public async Task<IActionResult> GetActiveSessions()
        => Ok(await _service.GetActiveSessionsAsync());

    [HttpGet("reports/wait-stats")]
    public async Task<IActionResult> GetWaitStats([FromQuery] int topN = 25)
        => Ok(await _service.GetWaitStatisticsAsync(topN));

    [HttpGet("reports/resource-consumption")]
    public async Task<IActionResult> GetResourceConsumption()
        => Ok(await _service.GetResourceConsumptionAsync());

    [HttpGet("alerts")]
    public async Task<IActionResult> GetAlerts([FromQuery] int daysBack = 30, [FromQuery] bool unacknowledgedOnly = false, [FromQuery] string? alertType = null)
        => Ok(await _service.GetAlertHistoryAsync(daysBack, unacknowledgedOnly, alertType));

    [HttpPost("alerts/scan")]
    public async Task<IActionResult> ScanAlerts()
    {
        await _service.RunAllAlertsAsync();
        return Ok(new { Message = "Alert scan completed." });
    }

    [HttpPost("alerts/{alertId:int}/acknowledge")]
    public async Task<IActionResult> AcknowledgeAlert(int alertId)
    {
        try
        {
            var result = await _service.AcknowledgeAlertAsync(alertId);
            return result is null ? NotFound() : Ok(result);
        }
        catch (Microsoft.Data.SqlClient.SqlException ex) when (ex.Number == 50020)
        {
            return NotFound(new { Message = ex.Message });
        }
    }

    [HttpGet("thresholds")]
    public async Task<IActionResult> GetThresholds()
        => Ok(await _service.GetThresholdsAsync());

    [HttpPut("thresholds/{thresholdCode}")]
    public async Task<IActionResult> UpdateThreshold(string thresholdCode, [FromBody] UpdateThresholdRequestDto request)
    {
        try
        {
            var result = await _service.UpdateThresholdAsync(thresholdCode, request);
            return result is null ? NotFound() : Ok(result);
        }
        catch (Microsoft.Data.SqlClient.SqlException ex) when (ex.Number == 50021)
        {
            return NotFound(new { Message = ex.Message });
        }
    }

    [HttpPost("capture-metrics")]
    public async Task<IActionResult> CaptureMetrics()
    {
        await _service.CaptureMetricsAsync();
        return Ok(new { Message = "Metrics captured." });
    }

    [HttpPost("export/capacity-summary-excel")]
    public async Task<IActionResult> ExportCapacityExcel()
        => File(await _service.ExportCapacitySummaryExcelAsync(),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "CapacityPlanningSummary.xlsx");

    [HttpPost("export/sql-performance-excel")]
    public async Task<IActionResult> ExportSqlPerfExcel([FromBody] CapPerfFilterDto? filter)
        => File(await _service.ExportSqlPerformanceExcelAsync(filter?.TopN ?? 25),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "SqlPerformanceAnalysis.xlsx");

    [HttpPost("export/storage-excel")]
    public async Task<IActionResult> ExportStorageExcel()
        => File(await _service.ExportStorageExcelAsync(),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "StorageUtilization.xlsx");

    [HttpPost("export/resource-excel")]
    public async Task<IActionResult> ExportResourceExcel()
        => File(await _service.ExportResourceExcelAsync(),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "ResourceConsumption.xlsx");

    [HttpPost("export/alert-history-excel")]
    public async Task<IActionResult> ExportAlertsExcel([FromBody] CapPerfFilterDto? filter)
        => File(await _service.ExportAlertHistoryExcelAsync(filter?.DaysBack ?? 30),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "AlertHistory.xlsx");

    [HttpPost("export/capacity-summary-csv")]
    public async Task<IActionResult> ExportCapacityCsv()
        => File(Encoding.UTF8.GetBytes(await _service.ExportCapacitySummaryCsvAsync()), "text/csv", "CapacityPlanningSummary.csv");

    [HttpPost("export/sql-performance-csv")]
    public async Task<IActionResult> ExportSqlPerfCsv([FromBody] CapPerfFilterDto? filter)
        => File(Encoding.UTF8.GetBytes(await _service.ExportSqlPerformanceCsvAsync(filter?.TopN ?? 25)), "text/csv", "SqlPerformanceAnalysis.csv");

    [HttpPost("export/storage-csv")]
    public async Task<IActionResult> ExportStorageCsv()
        => File(Encoding.UTF8.GetBytes(await _service.ExportStorageCsvAsync()), "text/csv", "StorageUtilization.csv");

    [HttpPost("export/resource-csv")]
    public async Task<IActionResult> ExportResourceCsv()
        => File(Encoding.UTF8.GetBytes(await _service.ExportResourceCsvAsync()), "text/csv", "ResourceConsumption.csv");

    [HttpPost("export/alert-history-csv")]
    public async Task<IActionResult> ExportAlertsCsv([FromBody] CapPerfFilterDto? filter)
        => File(Encoding.UTF8.GetBytes(await _service.ExportAlertHistoryCsvAsync(filter?.DaysBack ?? 30)), "text/csv", "AlertHistory.csv");
}
