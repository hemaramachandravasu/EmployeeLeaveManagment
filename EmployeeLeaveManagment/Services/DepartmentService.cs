using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;

namespace EmployeeLeaveManagment.Services
{
  public class DepartmentService : IDepartmentService
    {
        private readonly IDepartmentRepository _departmentRepository;

        public DepartmentService(IDepartmentRepository departmentRepository)
        {
            _departmentRepository = departmentRepository;
        }

        public async Task<IEnumerable<DepartmentDto>> GetAllDepartmentsAsync()
        {
            return await _departmentRepository.GetAllDepartmentsAsync();
        }

        public async Task<DepartmentDto?> GetDepartmentByIdAsync(int departmentId)
        {
            return await _departmentRepository.GetDepartmentByIdAsync(departmentId);
        }

        public async Task<int> AddDepartmentAsync(DepartmentDto department)
        {
            return await _departmentRepository.AddDepartmentAsync(department);
        }

        public async Task<int> UpdateDepartmentAsync(DepartmentDto department)
        {
            return await _departmentRepository.UpdateDepartmentAsync(department);
        }

        public async Task<int> DeleteDepartmentAsync(int departmentId)
        {
            return await _departmentRepository.DeleteDepartmentAsync(departmentId);
        }
    }
}