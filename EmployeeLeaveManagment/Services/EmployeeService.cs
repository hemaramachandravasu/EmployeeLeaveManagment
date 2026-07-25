using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Helpers;

namespace EmployeeLeaveManagment.Services
{
    public class EmployeeService : IEmployeeService
    {
        private readonly IEmployeeRepository _employeeRepository;

        public EmployeeService(IEmployeeRepository employeeRepository)
        {
            _employeeRepository = employeeRepository;
        }

        public async Task<IEnumerable<EmployeeDto>> GetAllEmployeesAsync()
        {
            return await _employeeRepository.GetAllEmployeesAsync();
        }

        public async Task<EmployeeDto?> GetEmployeeByIdAsync(int employeeId)
        {
            if (employeeId <= 0)
                return null;

            return await _employeeRepository.GetEmployeeByIdAsync(employeeId);
        }

        public async Task<int> AddEmployeeAsync(EmployeeDto employee)
        {
            if (EmployeeValidator.ValidateCreate(employee) != null)
                return 0;

            return await _employeeRepository.AddEmployeeAsync(employee);
        }

        public async Task<int> UpdateEmployeeAsync(EmployeeDto employee)
        {
            if (employee.EmployeeId <= 0)
                return 0;

            if (EmployeeValidator.ValidateCreate(employee) != null)
                return 0;

            return await _employeeRepository.UpdateEmployeeAsync(employee);
        }

        public async Task<int> DeleteEmployeeAsync(int employeeId)
        {
            if (employeeId <= 0)
                return 0;

            return await _employeeRepository.DeleteEmployeeAsync(employeeId);
        }

        public async Task<IEnumerable<EmployeeDto>> SearchEmployeesAsync(string keyword)
        {
            if (string.IsNullOrWhiteSpace(keyword))
                return Enumerable.Empty<EmployeeDto>();

            return await _employeeRepository.SearchEmployeesAsync(keyword, null);
        }

        public async Task<IEnumerable<EmployeeDto>> GetEmployeesByDepartmentAsync(int departmentId)
        {
            if (departmentId <= 0)
                return Enumerable.Empty<EmployeeDto>();

            return await _employeeRepository.GetEmployeesByDepartmentAsync(departmentId);
        }
    }
}
