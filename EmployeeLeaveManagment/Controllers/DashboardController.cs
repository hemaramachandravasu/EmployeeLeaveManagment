using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Helpers;
using EmployeeLeaveManagment.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace EmployeeLeaveManagment.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public class DashboardController : ControllerBase
{
    private readonly IDashboardService _dashboardService;

    public DashboardController(IDashboardService dashboardService)
    {
        _dashboardService = dashboardService;
    }

    /// <summary>Aggregate KPI counts for the admin dashboard header.</summary>
    [HttpGet]
    public async Task<IActionResult> GetDashboard()
    {
        var result = await _dashboardService.GetDashboardDataAsync();
        return Ok(result);
    }

    /// <summary>Department-wise leave counts for dashboard charts.</summary>
    [HttpGet("department-leaves")]
    public async Task<IActionResult> GetDepartmentLeaveCounts([FromQuery] int? year)
    {
        if (year.HasValue && (year < 2000 || year > 2100))
            return BadRequest(new { Message = "Year must be between 2000 and 2100." });

        var result = await _dashboardService.GetDepartmentLeaveCountsAsync(year);
        return Ok(result);
    }

    /// <summary>Monthly leave utilization trend for dashboard line charts.</summary>
    [HttpGet("monthly-trend")]
    public async Task<IActionResult> GetMonthlyUtilizationTrend([FromQuery] int? year)
    {
        if (year.HasValue && (year < 2000 || year > 2100))
            return BadRequest(new { Message = "Year must be between 2000 and 2100." });

        var result = await _dashboardService.GetMonthlyUtilizationTrendAsync(year);
        return Ok(result);
    }

    /// <summary>Lightweight pending-requests summary derived from dashboard KPIs.</summary>
    [HttpGet("pending-summary")]
    public async Task<IActionResult> GetPendingSummary()
    {
        var dashboard = await _dashboardService.GetDashboardDataAsync();
        return Ok(new
        {
            dashboard.PendingLeaves,
            dashboard.TotalLeaveRequests,
            dashboard.ApprovedLeaves,
            dashboard.RejectedLeaves
        });
    }
}
