using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Helpers;
using EmployeeLeaveManagment.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

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

        [HttpGet("{id:int}")]
        public async Task<IActionResult> GetLeaveById(int id)
        {
            if (id <= 0)
                return BadRequest(new { Message = "id must be a positive integer." });

            try
            {
                var result = await _leaveService.GetLeaveByIdAsync(id);

                if (result == null)
                    return NotFound(new { Message = $"Leave request {id} was not found." });

                return Ok(result);
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        [HttpPost]
        public async Task<IActionResult> ApplyLeave([FromBody] LeaveRequestDto? leaveRequest)
        {
            string? validationError = LeaveRequestValidator.ValidateApply(leaveRequest);
            if (validationError != null)
                return BadRequest(new { Message = validationError });

            if (!ModelState.IsValid)
                return ValidationProblem(ModelState);

            try
            {
                var result = await _leaveService.ApplyLeaveAsync(leaveRequest!);

                if (result > 0)
                    return Ok(new { Message = "Leave applied successfully.", LeaveRequestId = result });

                return BadRequest(new { Message = LeaveRequestValidator.MapApplyResult(result) });
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        [HttpPut]
        public async Task<IActionResult> UpdateLeave([FromBody] LeaveRequestDto? leaveRequest)
        {
            string? validationError = LeaveRequestValidator.ValidateUpdate(leaveRequest);
            if (validationError != null)
                return BadRequest(new { Message = validationError });

            if (!ModelState.IsValid)
                return ValidationProblem(ModelState);

            try
            {
                var result = await _leaveService.UpdateLeaveAsync(leaveRequest!);

                if (result > 0)
                    return Ok(new { Message = "Leave updated successfully." });

                return BadRequest(new { Message = LeaveRequestValidator.MapUpdateResult(result) });
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        [HttpDelete("{id:int}")]
        public async Task<IActionResult> DeleteLeave(int id)
        {
            if (id <= 0)
                return BadRequest(new { Message = "id must be a positive integer." });

            try
            {
                var result = await _leaveService.DeleteLeaveAsync(id);

                if (result > 0)
                    return Ok(new { Message = "Leave cancelled successfully." });

                if (result == -1)
                    return NotFound(new { Message = $"Leave request {id} was not found." });

                return BadRequest(new { Message = "Unable to cancel leave request." });
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        [HttpPut("approve/{leaveRequestId:int}")]
        public async Task<IActionResult> ApproveLeave(
            int leaveRequestId,
            [FromQuery] int? approvedBy,
            [FromQuery] string? remarks)
        {
            string? validationError = LeaveRequestValidator.ValidateApproval(leaveRequestId, approvedBy);
            if (validationError != null)
                return BadRequest(new { Message = validationError });

            if (remarks is { Length: > 500 })
                return BadRequest(new { Message = "Remarks cannot exceed 500 characters." });

            try
            {
                var result = await _leaveService.ApproveLeaveAsync(
                    leaveRequestId,
                    approvedBy!.Value,
                    remarks ?? string.Empty);

                if (result > 0)
                {
                    var leave = await _leaveService.GetLeaveByIdAsync(leaveRequestId);
                    return Ok(new
                    {
                        Message = "Leave approved successfully.",
                        Leave = leave
                    });
                }

                return BadRequest(new { Message = LeaveRequestValidator.MapApprovalResult(result, "approved") });
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        [HttpPut("reject/{leaveRequestId:int}")]
        public async Task<IActionResult> RejectLeave(
            int leaveRequestId,
            [FromQuery] int? approvedBy,
            [FromQuery] string? remarks)
        {
            string? validationError = LeaveRequestValidator.ValidateApproval(leaveRequestId, approvedBy);
            if (validationError != null)
                return BadRequest(new { Message = validationError });

            if (remarks is { Length: > 500 })
                return BadRequest(new { Message = "Remarks cannot exceed 500 characters." });

            try
            {
                var result = await _leaveService.RejectLeaveAsync(
                    leaveRequestId,
                    approvedBy!.Value,
                    remarks ?? string.Empty);

                if (result > 0)
                {
                    var leave = await _leaveService.GetLeaveByIdAsync(leaveRequestId);
                    return Ok(new
                    {
                        Message = "Leave rejected successfully.",
                        Leave = leave
                    });
                }

                return BadRequest(new { Message = LeaveRequestValidator.MapApprovalResult(result, "rejected") });
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        [HttpGet("employee/{employeeId:int}")]
        public async Task<IActionResult> GetLeavesByEmployee(int employeeId)
        {
            if (employeeId <= 0)
                return BadRequest(new { Message = "employeeId must be a positive integer." });

            try
            {
                var result = await _leaveService.GetLeavesByEmployeeAsync(employeeId);
                return Ok(result);
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        [HttpGet("pending")]
        public async Task<IActionResult> GetPendingLeaves()
        {
            try
            {
                var result = await _leaveService.GetPendingLeavesAsync();
                return Ok(result);
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
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

            try
            {
                var result = await _leaveService.GetLeavesByDateRangeAsync(fromDate.Value, toDate.Value);
                return Ok(result);
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        private ObjectResult DatabaseError(SqlException ex)
        {
            var pd = new ProblemDetails
            {
                Title = "Database error",
                Detail = ex.Message,
                Status = StatusCodes.Status500InternalServerError,
                Type = "https://tools.ietf.org/html/rfc9110#section-15.5.1"
            };

            return StatusCode(StatusCodes.Status500InternalServerError, pd);
        }
    }
}
