using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

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
            var departments = await _departmentService.GetAllDepartmentsAsync();
            return Ok(departments);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetDepartmentById(int id)
        {
            var department = await _departmentService.GetDepartmentByIdAsync(id);

            if (department == null)
                return NotFound();

            return Ok(department);
        }

        [HttpPost]
        public async Task<IActionResult> AddDepartment([FromBody] DepartmentDto? department)
        {
            if (department == null)
                return BadRequest(new { Message = "Department request body is required." });

            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var result = await _departmentService.AddDepartmentAsync(department);

            if (result == -1)
                return BadRequest(new { Message = "Department already exists." });

            if (result > 0)
                return Ok(new { Message = "Department added successfully." });

            return BadRequest(new { Message = "Unable to add department. Verify request body values." });
        }

        [HttpPut]
        public async Task<IActionResult> UpdateDepartment([FromBody] DepartmentDto? department)
        {
            if (department == null)
                return BadRequest(new { Message = "Department request body is required." });

            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var result = await _departmentService.UpdateDepartmentAsync(department);

            if (result > 0)
                return Ok(new { Message = "Department updated successfully." });

            return BadRequest(new { Message = "Unable to update department. Verify request body values." });
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteDepartment(int id)
        {
            var result = await _departmentService.DeleteDepartmentAsync(id);

            if (result > 0)
                return Ok(new { Message = "Department deleted successfully." });

            if (result == -2)
                return BadRequest(new { Message = "Department cannot be deleted because it is referenced by other records." });

            return NotFound(new { Message = "Department not found." });
        }
    }
}