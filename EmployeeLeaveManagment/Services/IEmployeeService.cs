using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Models;
using System.Collections.Generic;

namespace EmployeeLeaveManagment.Services
{
    public interface IEmployeeService
    {
        Task<IEnumerable<EmployeeDto>> GetAllEmployeesAsync();

        Task<EmployeeDto?> GetEmployeeByIdAsync(int employeeId);

        Task<int> AddEmployeeAsync(EmployeeDto employee);

        Task<int> UpdateEmployeeAsync(EmployeeDto employee);

        Task<int> DeleteEmployeeAsync(int employeeId);

        Task<IEnumerable<EmployeeDto>> SearchEmployeesAsync(string keyword);

        Task<IEnumerable<EmployeeDto>> GetEmployeesByDepartmentAsync(int departmentId);
    }
}
