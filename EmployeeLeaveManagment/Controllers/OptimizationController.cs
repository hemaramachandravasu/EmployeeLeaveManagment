using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Text;

namespace EmployeeLeaveManagment.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public class OptimizationController : ControllerBase
{
    private readonly IOptimizationService _service;

    public OptimizationController(IOptimizationService service)
    {
        _service = service;
    }

    /// <summary>Database performance summary (size, sessions, partitioned tables).</summary>
    [HttpGet("performance-summary")]
    public async Task<IActionResult> GetPerformanceSummary()
        => Ok(await _service.GetPerformanceSummaryAsync());

    [HttpGet("reports/query-execution")]
    public async Task<IActionResult> GetQueryExecution([FromQuery] int topN = 25)
    {
        if (topN < 1 || topN > 100)
            return BadRequest(new { Message = "topN must be between 1 and 100." });
        return Ok(await _service.GetQueryExecutionStatsAsync(topN));
    }

    [HttpGet("reports/table-growth")]
    public async Task<IActionResult> GetTableGrowth()
        => Ok(await _service.GetTableGrowthAsync());

    [HttpGet("reports/storage-utilization")]
    public async Task<IActionResult> GetStorageUtilization()
        => Ok(await _service.GetStorageUtilizationAsync());

    [HttpGet("reports/index-health")]
    public async Task<IActionResult> GetIndexHealth([FromQuery] int minPageCount = 50)
        => Ok(await _service.GetIndexHealthAsync(minPageCount));

    [HttpGet("reports/partition-info")]
    public async Task<IActionResult> GetPartitionInfo([FromQuery] string? tableName = null)
        => Ok(await _service.GetPartitionInfoAsync(tableName));

    [HttpGet("health-check")]
    public async Task<IActionResult> GetHealthCheck()
        => Ok(await _service.GetHealthCheckAsync());

    [HttpPost("export/performance-summary-excel")]
    public async Task<IActionResult> ExportPerformanceSummaryExcel()
    {
        var bytes = await _service.ExportPerformanceSummaryExcelAsync();
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "PerformanceSummary.xlsx");
    }

    [HttpPost("export/query-execution-excel")]
    public async Task<IActionResult> ExportQueryExecutionExcel([FromBody] OptimizationFilterDto? filter)
    {
        var bytes = await _service.ExportQueryExecutionStatsExcelAsync(filter?.TopN ?? 25);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "QueryExecutionStats.xlsx");
    }

    [HttpPost("export/table-growth-excel")]
    public async Task<IActionResult> ExportTableGrowthExcel()
    {
        var bytes = await _service.ExportTableGrowthExcelAsync();
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "TableGrowth.xlsx");
    }

    [HttpPost("export/storage-utilization-excel")]
    public async Task<IActionResult> ExportStorageUtilizationExcel()
    {
        var bytes = await _service.ExportStorageUtilizationExcelAsync();
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "StorageUtilization.xlsx");
    }

    [HttpPost("export/index-health-excel")]
    public async Task<IActionResult> ExportIndexHealthExcel([FromBody] OptimizationFilterDto? filter)
    {
        var bytes = await _service.ExportIndexHealthExcelAsync(filter?.MinPageCount ?? 50);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "OptIndexHealth.xlsx");
    }

    [HttpPost("export/partition-info-excel")]
    public async Task<IActionResult> ExportPartitionInfoExcel([FromBody] OptimizationFilterDto? filter)
    {
        var bytes = await _service.ExportPartitionInfoExcelAsync(filter?.TableName);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "PartitionInfo.xlsx");
    }

    [HttpPost("export/performance-summary-csv")]
    public async Task<IActionResult> ExportPerformanceSummaryCsv()
    {
        var csv = await _service.ExportPerformanceSummaryCsvAsync();
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "PerformanceSummary.csv");
    }

    [HttpPost("export/query-execution-csv")]
    public async Task<IActionResult> ExportQueryExecutionCsv([FromBody] OptimizationFilterDto? filter)
    {
        var csv = await _service.ExportQueryExecutionStatsCsvAsync(filter?.TopN ?? 25);
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "QueryExecutionStats.csv");
    }

    [HttpPost("export/table-growth-csv")]
    public async Task<IActionResult> ExportTableGrowthCsv()
    {
        var csv = await _service.ExportTableGrowthCsvAsync();
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "TableGrowth.csv");
    }

    [HttpPost("export/storage-utilization-csv")]
    public async Task<IActionResult> ExportStorageUtilizationCsv()
    {
        var csv = await _service.ExportStorageUtilizationCsvAsync();
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "StorageUtilization.csv");
    }

    [HttpPost("export/index-health-csv")]
    public async Task<IActionResult> ExportIndexHealthCsv([FromBody] OptimizationFilterDto? filter)
    {
        var csv = await _service.ExportIndexHealthCsvAsync(filter?.MinPageCount ?? 50);
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "OptIndexHealth.csv");
    }

    [HttpPost("export/partition-info-csv")]
    public async Task<IActionResult> ExportPartitionInfoCsv([FromBody] OptimizationFilterDto? filter)
    {
        var csv = await _service.ExportPartitionInfoCsvAsync(filter?.TableName);
        return File(Encoding.UTF8.GetBytes(csv), "text/csv", "PartitionInfo.csv");
    }
}
