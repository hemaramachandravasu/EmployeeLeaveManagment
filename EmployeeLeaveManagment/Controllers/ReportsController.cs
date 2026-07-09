using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Helpers;
using EmployeeLeaveManagment.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace EmployeeLeaveManagment.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public class ReportController : ControllerBase
{
    private readonly IReportService _reportService;

    public ReportController(IReportService reportService)
    {
        _reportService = reportService;
    }

    [HttpPost("employee-summary")]
    public async Task<IActionResult> GetEmployeeLeaveSummaryPost([FromBody] ReportFilterDto? filter)
    {
        var error = ReportFilterValidator.Validate(filter);
        if (error != null) return BadRequest(new { Message = error });
        var result = await _reportService.GetEmployeeLeaveSummaryAsync(filter!);
        return Ok(result);
    }

    [HttpGet("employee-summary")]
    public async Task<IActionResult> GetEmployeeLeaveSummary([FromQuery] ReportFilterDto filter)
    {
        var error = ReportFilterValidator.Validate(filter, requireBody: false);
        if (error != null) return BadRequest(new { Message = error });

        var result = await _reportService.GetEmployeeLeaveSummaryAsync(filter);
        return Ok(result);
    }

    [HttpPost("monthly-utilization")]
    public async Task<IActionResult> GetMonthlyLeaveUtilizationPost([FromBody] ReportFilterDto? filter)
    {
        var error = ReportFilterValidator.Validate(filter);
        if (error != null) return BadRequest(new { Message = error });
        var result = await _reportService.GetMonthlyLeaveUtilizationAsync(filter!);
        return Ok(result);
    }

    [HttpGet("monthly-utilization")]
    public async Task<IActionResult> GetMonthlyLeaveUtilization([FromQuery] ReportFilterDto filter)
    {
        var error = ReportFilterValidator.Validate(filter, requireBody: false);
        if (error != null) return BadRequest(new { Message = error });

        var result = await _reportService.GetMonthlyLeaveUtilizationAsync(filter);
        return Ok(result);
    }

    [HttpPost("department-statistics")]
    public async Task<IActionResult> GetDepartmentLeaveStatisticsPost([FromBody] ReportFilterDto? filter)
    {
        var error = ReportFilterValidator.Validate(filter);
        if (error != null) return BadRequest(new { Message = error });
        var result = await _reportService.GetDepartmentLeaveStatisticsAsync(filter!);
        return Ok(result);
    }

    [HttpGet("department-statistics")]
    public async Task<IActionResult> GetDepartmentLeaveStatistics([FromQuery] ReportFilterDto filter)
    {
        var error = ReportFilterValidator.Validate(filter, requireBody: false);
        if (error != null) return BadRequest(new { Message = error });

        var result = await _reportService.GetDepartmentLeaveStatisticsAsync(filter);
        return Ok(result);
    }

    [HttpGet("pending")]
    public async Task<IActionResult> GetPendingLeaveRequests()
    {
        var result = await _reportService.GetPendingLeaveRequestsAsync();
        return Ok(result);
    }

    [HttpPost("export/employee-excel")]
    public async Task<IActionResult> ExportEmployeeExcel([FromBody] ReportFilterDto? filter)
    {
        var error = ReportFilterValidator.Validate(filter);
        if (error != null) return BadRequest(new { Message = error });

        var fileBytes = await _reportService.ExportEmployeeLeaveSummaryExcelAsync(filter!);
        return File(fileBytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "EmployeeLeaveSummary.xlsx");
    }

    [HttpPost("export/department-excel")]
    public async Task<IActionResult> ExportDepartmentExcel([FromBody] ReportFilterDto? filter)
    {
        var error = ReportFilterValidator.Validate(filter);
        if (error != null) return BadRequest(new { Message = error });

        var fileBytes = await _reportService.ExportDepartmentStatisticsExcelAsync(filter!);
        return File(fileBytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "DepartmentStatistics.xlsx");
    }

    [HttpPost("export/employee-csv")]
    public async Task<IActionResult> ExportEmployeeCsv([FromBody] ReportFilterDto? filter)
    {
        var error = ReportFilterValidator.Validate(filter);
        if (error != null) return BadRequest(new { Message = error });

        var csvData = await _reportService.ExportEmployeeLeaveSummaryCsvAsync(filter!);
        return File(System.Text.Encoding.UTF8.GetBytes(csvData), "text/csv", "EmployeeLeaveSummary.csv");
    }

    [HttpPost("export/department-csv")]
    public async Task<IActionResult> ExportDepartmentCsv([FromBody] ReportFilterDto? filter)
    {
        var error = ReportFilterValidator.Validate(filter);
        if (error != null) return BadRequest(new { Message = error });

        var csvData = await _reportService.ExportDepartmentStatisticsCsvAsync(filter!);
        return File(System.Text.Encoding.UTF8.GetBytes(csvData), "text/csv", "DepartmentStatistics.csv");
    }
}
