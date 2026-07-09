using EmployeeLeaveManagment.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace EmployeeLeaveManagment.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public class AnalyticsController : ControllerBase
{
    private readonly IAnalyticsService _analyticsService;

    public AnalyticsController(IAnalyticsService analyticsService)
    {
        _analyticsService = analyticsService;
    }

    [HttpGet("leave-trend")]
    public async Task<IActionResult> GetLeaveTrendAnalysis([FromQuery] int? year)
    {
        if (year.HasValue && (year < 2000 || year > 2100))
            return BadRequest(new { Message = "Year must be between 2000 and 2100." });

        var result = await _analyticsService.GetLeaveTrendAnalysisAsync(year);
        return Ok(result);
    }

    [HttpGet("department-comparison")]
    public async Task<IActionResult> GetDepartmentComparison([FromQuery] int? year)
    {
        if (year.HasValue && (year < 2000 || year > 2100))
            return BadRequest(new { Message = "Year must be between 2000 and 2100." });

        var result = await _analyticsService.GetDepartmentComparisonAsync(year);
        return Ok(result);
    }

    [HttpGet("frequent-leave-pattern")]
    public async Task<IActionResult> GetFrequentLeavePattern()
    {
        var result = await _analyticsService.GetFrequentLeavePatternAsync();
        return Ok(result);
    }

    [HttpGet("forecast-leave-utilization")]
    public async Task<IActionResult> GetForecastLeaveUtilization()
    {
        var result = await _analyticsService.GetForecastLeaveUtilizationAsync();
        return Ok(result);
    }
}
