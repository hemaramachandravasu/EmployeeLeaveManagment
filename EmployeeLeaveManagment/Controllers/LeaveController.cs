using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace EmployeeLeaveManagment.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class LeaveController : ControllerBase
    {
        private readonly ILeaveService _leaveService;

        public LeaveController(ILeaveService leaveService)
        {
            _leaveService = leaveService;
        }

        [HttpGet]
        public async Task<IActionResult> GetAllLeaves()
        {
            var result = await _leaveService.GetAllLeavesAsync();
            return Ok(result);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetLeaveById(int id)
        {
            var result = await _leaveService.GetLeaveByIdAsync(id);

            if (result == null)
                return NotFound();

            return Ok(result);
        }

        [HttpPost]
        public async Task<IActionResult> ApplyLeave([FromBody] LeaveRequestDto? leaveRequest)
        {
            if (leaveRequest == null)
                return BadRequest(new { Message = "Leave request body is required." });

            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            if (leaveRequest.EmployeeId <= 0 || leaveRequest.LeaveTypeId <= 0)
                return BadRequest(new { Message = "EmployeeId and LeaveTypeId must be valid positive values." });

            if (leaveRequest.StartDate == default || leaveRequest.EndDate == default || leaveRequest.StartDate > leaveRequest.EndDate)
                return BadRequest(new { Message = "Invalid leave dates. StartDate must be before or equal to EndDate." });

            var result = await _leaveService.ApplyLeaveAsync(leaveRequest);

            if (result > 0)
                return Ok(new { Message = "Leave applied successfully.", LeaveRequestId = result });

            return BadRequest(new { Message = "Unable to apply leave request. Verify input values and employee/leavetype exist." });
        }

        [HttpPut]
        public async Task<IActionResult> UpdateLeave([FromBody] LeaveRequestDto leaveRequest)
        {
            var result = await _leaveService.UpdateLeaveAsync(leaveRequest);

            if (result > 0)
                return Ok(new { Message = "Leave updated successfully." });

            return BadRequest();
        }
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteLeave(int id)
        {
            var result = await _leaveService.DeleteLeaveAsync(id);

            if (result > 0)
                return Ok(new { Message = "Leave deleted successfully." });

            return BadRequest(new { Message = "Unable to delete leave request." });
        }

        [HttpPut("approve/{leaveRequestId}")]
        public async Task<IActionResult> ApproveLeave(
            int leaveRequestId,
            [FromQuery] int? approvedBy,
            [FromQuery] string? remarks)
        {
            if (!approvedBy.HasValue || approvedBy.Value <= 0)
                return BadRequest(new { Message = "approvedBy query parameter is required and must be a valid employee id." });

            var result = await _leaveService.ApproveLeaveAsync(
                leaveRequestId,
                approvedBy.Value,
                remarks ?? string.Empty);

            if (result > 0)
                return Ok(new { Message = "Leave approved successfully." });

            return BadRequest(new { Message = "Unable to approve leave request. Verify leave request id and approvedBy employee id." });
        }

        [HttpPut("reject/{leaveRequestId}")]
        public async Task<IActionResult> RejectLeave(
            int leaveRequestId,
            [FromQuery] int? approvedBy,
            [FromQuery] string? remarks)
        {
            if (!approvedBy.HasValue || approvedBy.Value <= 0)
                return BadRequest(new { Message = "approvedBy query parameter is required and must be a valid employee id." });

            var result = await _leaveService.RejectLeaveAsync(
                leaveRequestId,
                approvedBy.Value,
                remarks ?? string.Empty);

            if (result > 0)
                return Ok(new { Message = "Leave rejected successfully." });

            return BadRequest(new { Message = "Unable to reject leave request. Verify leave request id and approvedBy employee id." });
        }

        [HttpGet("employee/{employeeId}")]
        public async Task<IActionResult> GetLeavesByEmployee(int employeeId)
        {
            if (employeeId <= 0)
                return BadRequest(new { Message = "employeeId must be a positive integer." });

            var result = await _leaveService.GetLeavesByEmployeeAsync(employeeId);
            return Ok(result);
        }

        [HttpGet("pending")]
        public async Task<IActionResult> GetPendingLeaves()
        {
            var result = await _leaveService.GetPendingLeavesAsync();
            return Ok(result);
        }

        [HttpGet("daterange")]
        public async Task<IActionResult> GetLeavesByDateRange(
            [FromQuery] DateTime? fromDate,
            [FromQuery] DateTime? toDate)
        {
            if (!fromDate.HasValue || !toDate.HasValue)
                return BadRequest(new { Message = "fromDate and toDate query parameters are required." });

            if (fromDate > toDate)
                return BadRequest(new { Message = "fromDate must be on or before toDate." });

            var result = await _leaveService.GetLeavesByDateRangeAsync(fromDate.Value, toDate.Value);
            return Ok(result);
        }
    }
}