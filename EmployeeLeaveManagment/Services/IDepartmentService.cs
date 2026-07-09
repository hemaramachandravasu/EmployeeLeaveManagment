using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Services
{
    public interface IDepartmentService
    {
        Task<IEnumerable<DepartmentDto>> GetAllDepartmentsAsync();

        Task<DepartmentDto?> GetDepartmentByIdAsync(int departmentId);

        Task<int> AddDepartmentAsync(DepartmentDto department);

        Task<int> UpdateDepartmentAsync(DepartmentDto department);

        Task<int> DeleteDepartmentAsync(int departmentId);
    }
}
