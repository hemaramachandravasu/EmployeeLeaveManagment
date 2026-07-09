using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Models;
using System.Collections.Generic;

namespace EmployeeLeaveManagment.Data
{
    public interface IEmployeeRepository
    {
        Task<IEnumerable<EmployeeDto>> GetAllEmployeesAsync();

        Task<EmployeeDto?> GetEmployeeByIdAsync(int employeeId);

        Task<int> AddEmployeeAsync(EmployeeDto employee);

        Task<int> UpdateEmployeeAsync(EmployeeDto employee);

        Task<int> DeleteEmployeeAsync(int employeeId);

        // Search & Filters
        Task<IEnumerable<EmployeeDto>> SearchEmployeesAsync(
            string? employeeName,
            int? departmentId);

        // Reports
        Task<IEnumerable<EmployeeDto>> GetEmployeesByDepartmentAsync(int departmentId);

        Task<int> GetEmployeeCountAsync();

        Task<int> GetActiveEmployeeCountAsync();
    }
}
