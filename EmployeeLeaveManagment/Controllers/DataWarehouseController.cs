using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace EmployeeLeaveManagment.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public class DataWarehouseController : ControllerBase
{
    private readonly IDataWarehouseService _dataWarehouseService;

    public DataWarehouseController(IDataWarehouseService dataWarehouseService)
    {
        _dataWarehouseService = dataWarehouseService;
    }

    /// <summary>Forecasted leave demand for the next 3 months by department.</summary>
    [HttpGet("forecast-demand")]
    public async Task<IActionResult> GetForecastDemand([FromQuery] DateTime? asOfDate)
    {
        var result = await _dataWarehouseService.GetForecastLeaveDemandAsync(asOfDate);
        return Ok(result);
    }

    /// <summary>Employee burnout risk indicator based on leave frequency patterns.</summary>
    [HttpGet("burnout-risk")]
    public async Task<IActionResult> GetBurnoutRisk([FromQuery] int lookbackDays = 180)
    {
        if (lookbackDays < 30 || lookbackDays > 730)
            return BadRequest(new { Message = "lookbackDays must be between 30 and 730." });

        var result = await _dataWarehouseService.GetEmployeeBurnoutRiskAsync(lookbackDays);
        return Ok(result);
    }

    /// <summary>Historically peak leave months and weeks.</summary>
    [HttpGet("peak-periods")]
    public async Task<IActionResult> GetPeakPeriods([FromQuery] int lookbackYears = 3, [FromQuery] int topN = 10)
    {
        var result = await _dataWarehouseService.GetPeakLeavePeriodsAsync(lookbackYears, topN);
        return Ok(result);
    }

    /// <summary>Month-over-month leave trend from the data warehouse.</summary>
    [HttpGet("month-over-month-trend")]
    public async Task<IActionResult> GetMonthOverMonthTrend([FromQuery] int? year)
    {
        if (year.HasValue && (year < 2000 || year > 2100))
            return BadRequest(new { Message = "Year must be between 2000 and 2100." });

        var result = await _dataWarehouseService.GetMonthOverMonthTrendAsync(year);
        return Ok(result);
    }

    /// <summary>Department utilization heatmap data (department x month).</summary>
    [HttpGet("department-heatmap")]
    public async Task<IActionResult> GetDepartmentHeatmap([FromQuery] int? year)
    {
        if (year.HasValue && (year < 2000 || year > 2100))
            return BadRequest(new { Message = "Year must be between 2000 and 2100." });

        var result = await _dataWarehouseService.GetDepartmentUtilizationHeatmapAsync(year);
        return Ok(result);
    }

    /// <summary>Top leave types by volume for the current or specified year.</summary>
    [HttpGet("top-leave-types")]
    public async Task<IActionResult> GetTopLeaveTypes([FromQuery] int? year, [FromQuery] int topN = 5)
    {
        if (year.HasValue && (year < 2000 || year > 2100))
            return BadRequest(new { Message = "Year must be between 2000 and 2100." });

        var result = await _dataWarehouseService.GetTopLeaveTypesByVolumeAsync(year, topN);
        return Ok(result);
    }

    /// <summary>Recent ETL run log entries from the warehouse.</summary>
    [HttpGet("etl-log")]
    public async Task<IActionResult> GetEtlLog([FromQuery] int topN = 20)
    {
        var result = await _dataWarehouseService.GetEtlRunLogAsync(topN);
        return Ok(result);
    }

    [HttpPost("export/forecast-demand-excel")]
    public async Task<IActionResult> ExportForecastDemandExcel([FromBody] DataWarehouseFilterDto? filter)
    {
        var bytes = await _dataWarehouseService.ExportForecastDemandExcelAsync(filter?.AsOfDate);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "ForecastLeaveDemand.xlsx");
    }

    [HttpPost("export/burnout-risk-excel")]
    public async Task<IActionResult> ExportBurnoutRiskExcel([FromBody] DataWarehouseFilterDto? filter)
    {
        var bytes = await _dataWarehouseService.ExportBurnoutRiskExcelAsync(filter?.LookbackDays ?? 180);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "BurnoutRisk.xlsx");
    }

    [HttpPost("export/peak-periods-excel")]
    public async Task<IActionResult> ExportPeakPeriodsExcel([FromBody] DataWarehouseFilterDto? filter)
    {
        var bytes = await _dataWarehouseService.ExportPeakPeriodsExcelAsync(filter?.LookbackYears ?? 3, filter?.TopN ?? 10);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "PeakLeavePeriods.xlsx");
    }

    [HttpPost("export/mom-trend-excel")]
    public async Task<IActionResult> ExportMomTrendExcel([FromBody] DataWarehouseFilterDto? filter)
    {
        var bytes = await _dataWarehouseService.ExportMomTrendExcelAsync(filter?.Year);
        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "MonthOverMonthTrend.xlsx");
    }

    [HttpPost("export/forecast-demand-csv")]
    public async Task<IActionResult> ExportForecastDemandCsv([FromBody] DataWarehouseFilterDto? filter)
    {
        var csv = await _dataWarehouseService.ExportForecastDemandCsvAsync(filter?.AsOfDate);
        return File(System.Text.Encoding.UTF8.GetBytes(csv), "text/csv", "ForecastLeaveDemand.csv");
    }

    [HttpPost("export/burnout-risk-csv")]
    public async Task<IActionResult> ExportBurnoutRiskCsv([FromBody] DataWarehouseFilterDto? filter)
    {
        var csv = await _dataWarehouseService.ExportBurnoutRiskCsvAsync(filter?.LookbackDays ?? 180);
        return File(System.Text.Encoding.UTF8.GetBytes(csv), "text/csv", "BurnoutRisk.csv");
    }

    [HttpPost("export/peak-periods-csv")]
    public async Task<IActionResult> ExportPeakPeriodsCsv([FromBody] DataWarehouseFilterDto? filter)
    {
        var csv = await _dataWarehouseService.ExportPeakPeriodsCsvAsync(filter?.LookbackYears ?? 3, filter?.TopN ?? 10);
        return File(System.Text.Encoding.UTF8.GetBytes(csv), "text/csv", "PeakLeavePeriods.csv");
    }

    [HttpPost("export/mom-trend-csv")]
    public async Task<IActionResult> ExportMomTrendCsv([FromBody] DataWarehouseFilterDto? filter)
    {
        var csv = await _dataWarehouseService.ExportMomTrendCsvAsync(filter?.Year);
        return File(System.Text.Encoding.UTF8.GetBytes(csv), "text/csv", "MonthOverMonthTrend.csv");
    }
}
