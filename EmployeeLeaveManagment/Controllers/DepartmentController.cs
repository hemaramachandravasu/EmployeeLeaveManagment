using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace EmployeeLeaveManagment.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class DepartmentController : ControllerBase
    {
        private readonly IDepartmentService _departmentService;

        public DepartmentController(IDepartmentService departmentService)
        {
            _departmentService = departmentService;
        }

        [HttpGet]
        public async Task<IActionResult> GetAllDepartments()
        {
            try
            {
                var departments = await _departmentService.GetAllDepartmentsAsync();
                return Ok(departments);
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        [HttpGet("{id:int}")]
        public async Task<IActionResult> GetDepartmentById(int id)
        {
            if (id <= 0)
                return BadRequest(new { Message = "id must be a positive integer." });

            try
            {
                var department = await _departmentService.GetDepartmentByIdAsync(id);

                if (department == null)
                    return NotFound(new { Message = $"Department {id} was not found." });

                return Ok(department);
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        [HttpPost]
        public async Task<IActionResult> AddDepartment([FromBody] DepartmentDto? department)
        {
            if (department == null)
                return BadRequest(new { Message = "Department request body is required." });

            if (string.IsNullOrWhiteSpace(department.DepartmentCode))
                return BadRequest(new { Message = "DepartmentCode is required." });

            if (string.IsNullOrWhiteSpace(department.DepartmentName))
                return BadRequest(new { Message = "DepartmentName is required." });

            if (!ModelState.IsValid)
                return ValidationProblem(ModelState);

            try
            {
                var result = await _departmentService.AddDepartmentAsync(department);

                if (result == -1)
                    return BadRequest(new { Message = "Department already exists." });

                if (result > 0)
                    return Ok(new { Message = "Department added successfully." });

                return BadRequest(new { Message = "Unable to add department. Verify request body values." });
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        [HttpPut]
        public async Task<IActionResult> UpdateDepartment([FromBody] DepartmentDto? department)
        {
            if (department == null)
                return BadRequest(new { Message = "Department request body is required." });

            if (department.DepartmentId <= 0)
                return BadRequest(new { Message = "DepartmentId must be a positive integer." });

            if (string.IsNullOrWhiteSpace(department.DepartmentCode))
                return BadRequest(new { Message = "DepartmentCode is required." });

            if (string.IsNullOrWhiteSpace(department.DepartmentName))
                return BadRequest(new { Message = "DepartmentName is required." });

            if (!ModelState.IsValid)
                return ValidationProblem(ModelState);

            try
            {
                var result = await _departmentService.UpdateDepartmentAsync(department);

                if (result > 0)
                    return Ok(new { Message = "Department updated successfully." });

                return BadRequest(new { Message = "Unable to update department. Verify request body values." });
            }
            catch (SqlException ex)
            {
                return DatabaseError(ex);
            }
        }

        [HttpDelete("{id:int}")]
        public async Task<IActionResult> DeleteDepartment(int id)
        {
            if (id <= 0)
                return BadRequest(new { Message = "id must be a positive integer." });

            try
            {
                var result = await _departmentService.DeleteDepartmentAsync(id);

                if (result > 0)
                    return Ok(new { Message = "Department deleted successfully." });

                if (result == -2)
                    return BadRequest(new { Message = "Department cannot be deleted because it is referenced by other records." });

                return NotFound(new { Message = "Department not found." });
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