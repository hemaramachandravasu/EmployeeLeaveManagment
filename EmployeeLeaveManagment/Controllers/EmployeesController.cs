using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Helpers;
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
            try
            {
                var employees = await _employeeService.GetAllEmployeesAsync();
                return Ok(employees);
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        // Declared before {id} so "search" is never ambiguous with id routes.
        [HttpGet("search")]
        public async Task<IActionResult> SearchEmployees([FromQuery] string? keyword)
        {
            if (string.IsNullOrWhiteSpace(keyword))
                return BadRequest(new { Message = "keyword query parameter is required for employee search." });

            try
            {
                var employees = await _employeeService.SearchEmployeesAsync(keyword);
                return Ok(employees);
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        [HttpGet("department/{departmentId:int}")]
        public async Task<IActionResult> GetEmployeesByDepartment(int departmentId)
        {
            if (departmentId <= 0)
                return BadRequest(new { Message = "departmentId must be a positive integer." });

            try
            {
                var employees = await _employeeService.GetEmployeesByDepartmentAsync(departmentId);
                return Ok(employees);
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        [HttpGet("{id:int}")]
        public async Task<IActionResult> GetEmployeeById(int id)
        {
            if (id <= 0)
                return BadRequest(new { Message = "id path parameter is required and must be a positive integer." });

            try
            {
                var employee = await _employeeService.GetEmployeeByIdAsync(id);

                if (employee == null)
                    return NotFound(new { Message = $"Employee {id} was not found." });

                return Ok(employee);
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
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
            string? validationError = EmployeeValidator.ValidateCreate(employee);
            if (validationError != null)
                return BadRequest(new { Message = validationError });

            if (!ModelState.IsValid)
                return ValidationProblem(ModelState);

            try
            {
                var result = await _employeeService.AddEmployeeAsync(employee!);

                if (result > 0)
                    return Ok(new { Message = "Employee added successfully.", EmployeeId = result });

                return BadRequest(new { Message = EmployeeValidator.MapAddResult(result) });
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        [HttpPut]
        public async Task<IActionResult> UpdateEmployee([FromBody] EmployeeDto? employee)
        {
            if (employee == null)
                return BadRequest(new { Message = "Employee request body is required." });

            if (employee.EmployeeId <= 0)
                return BadRequest(new { Message = "EmployeeId must be a positive integer." });

            string? validationError = EmployeeValidator.ValidateCreate(employee);
            if (validationError != null)
                return BadRequest(new { Message = validationError });

            if (!ModelState.IsValid)
                return ValidationProblem(ModelState);

            try
            {
                var result = await _employeeService.UpdateEmployeeAsync(employee);

                if (result > 0)
                    return Ok(new { Message = "Employee updated successfully." });

                if (result == -1)
                    return NotFound(new { Message = EmployeeValidator.MapUpdateResult(result) });

                return BadRequest(new { Message = EmployeeValidator.MapUpdateResult(result) });
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        [HttpDelete("{id:int}")]
        public async Task<IActionResult> DeleteEmployee(int id)
        {
            if (id <= 0)
                return BadRequest(new { Message = "id must be a positive integer." });

            try
            {
                var result = await _employeeService.DeleteEmployeeAsync(id);

                if (result > 0)
                    return Ok(new { Message = "Employee deleted successfully." });

                if (result is -1 or -2)
                    return NotFound(new { Message = EmployeeValidator.MapDeleteResult(result) });

                return BadRequest(new { Message = EmployeeValidator.MapDeleteResult(result) });
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
