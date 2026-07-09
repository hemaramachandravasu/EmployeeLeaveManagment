using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Models;
using EmployeeLeaveManagment.Services;
using System.Collections.Generic;

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
            return await _employeeRepository.GetEmployeeByIdAsync(employeeId);
        }

        public async Task<int> AddEmployeeAsync(EmployeeDto employee)
        {
            return await _employeeRepository.AddEmployeeAsync(employee);
        }

        public async Task<int> UpdateEmployeeAsync(EmployeeDto employee)
        {
            return await _employeeRepository.UpdateEmployeeAsync(employee);
        }
        public async Task<int> DeleteEmployeeAsync(int employeeId)
        {
            return await _employeeRepository.DeleteEmployeeAsync(employeeId);
        }

        public async Task<IEnumerable<EmployeeDto>> SearchEmployeesAsync(string keyword)
        {
            return await _employeeRepository.SearchEmployeesAsync(keyword, null);
        }

        public async Task<IEnumerable<EmployeeDto>> GetEmployeesByDepartmentAsync(int departmentId)
        {
            return await _employeeRepository.GetEmployeesByDepartmentAsync(departmentId);
        }
    }
}