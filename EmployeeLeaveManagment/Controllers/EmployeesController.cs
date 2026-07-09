using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Models;
using EmployeeLeaveManagment.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace EmployeeLeaveManagment.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class EmployeeController : ControllerBase
    {
        private readonly IEmployeeService _employeeService;

        public EmployeeController(IEmployeeService employeeService)
        {
            _employeeService = employeeService;
        }

        [HttpGet]
        public async Task<IActionResult> GetAllEmployees()
        {
            var employees = await _employeeService.GetAllEmployeesAsync();
            return Ok(employees);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetEmployeeById(int? id)
        {
            if (!id.HasValue || id.Value <= 0)
                return BadRequest(new { Message = "id path parameter is required and must be a positive integer." });

            try
            {
                var employee = await _employeeService.GetEmployeeByIdAsync(id.Value);

                if (employee == null)
                    return NotFound();

                return Ok(employee);
            }
            catch (SqlException ex)
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
            catch (Exception ex)
            {
                var pd = new ProblemDetails
                {
                    Title = "Internal server error",
                    Detail = ex.Message,
                    Status = StatusCodes.Status500InternalServerError,
                    Type = "https://tools.ietf.org/html/rfc9110#section-15.5.1"
                };

                return StatusCode(StatusCodes.Status500InternalServerError, pd);
            }
        }

        [HttpPost]
        public async Task<IActionResult> AddEmployee([FromBody] EmployeeDto? employee)
        {
            if (employee == null)
                return BadRequest(new { Message = "Employee request body is required." });

            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var result = await _employeeService.AddEmployeeAsync(employee);

            if (result == -1)
                return BadRequest(new { Message = "DepartmentId does not exist." });

            if (result > 0)
                return Ok(new { Message = "Employee added successfully." });

            return BadRequest(new { Message = "Unable to add employee. Verify request body values." });
        }

        [HttpPut]
        public async Task<IActionResult> UpdateEmployee([FromBody] EmployeeDto? employee)
        {
            if (employee == null)
                return BadRequest(new { Message = "Employee request body is required." });

            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var result = await _employeeService.UpdateEmployeeAsync(employee);

            if (result > 0)
                return Ok(new { Message = "Employee updated successfully." });

            return BadRequest(new { Message = "Unable to update employee. Verify request body values." });
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteEmployee(int id)
        {
            var result = await _employeeService.DeleteEmployeeAsync(id);

            if (result > 0)
                return Ok(new { Message = "Employee deleted successfully." });

            return BadRequest();
        }

        [HttpGet("search")]
        public async Task<IActionResult> SearchEmployees([FromQuery] string? keyword)
        {
            if (string.IsNullOrWhiteSpace(keyword))
                return BadRequest(new { Message = "keyword query parameter is required for employee search." });

            var employees = await _employeeService.SearchEmployeesAsync(keyword);
            return Ok(employees);
        }

        [HttpGet("department/{departmentId}")]
        public async Task<IActionResult> GetEmployeesByDepartment(int departmentId)
        {
            var employees = await _employeeService.GetEmployeesByDepartmentAsync(departmentId);
            return Ok(employees);
        }
    }
}