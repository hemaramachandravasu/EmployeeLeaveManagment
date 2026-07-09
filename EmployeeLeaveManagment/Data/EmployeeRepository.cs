using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.Data.SqlClient;
using System;
using System.Collections.Generic;
using System.Data;

namespace EmployeeLeaveManagment.Data
{
 
    public class EmployeeRepository : IEmployeeRepository
    {
        private readonly ISqlConnectionFactory _connectionFactory;

        public EmployeeRepository(ISqlConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        public async Task<IEnumerable<EmployeeDto>> GetAllEmployeesAsync()
        {
            List<EmployeeDto> employees = new();

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new SqlCommand(@"
                SELECT 
                    EmployeeId,
                    EmployeeCode,
                    FirstName,
                    LastName,
                    Gender,
                    DateOfBirth,
                    MobileNumber,
                    Email,
                    DepartmentId,
                    ManagerId,
                    JoinDate,
                    Salary,
                    Address,
                    IsActive
                FROM Employees", connection);

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                employees.Add(new EmployeeDto
                {
                    EmployeeId = Convert.ToInt32(reader["EmployeeId"]),
                    EmployeeCode = reader["EmployeeCode"].ToString()!,
                    FirstName = reader["FirstName"].ToString()!,
                    LastName = reader["LastName"]?.ToString(),
                    Gender = reader["Gender"].ToString()!,
                    DateOfBirth = Convert.ToDateTime(reader["DateOfBirth"]),
                    MobileNumber = reader["MobileNumber"].ToString()!,
                    Email = reader["Email"].ToString()!,
                    DepartmentId = Convert.ToInt32(reader["DepartmentId"]),
                    ManagerId = reader["ManagerId"] == DBNull.Value
                        ? null
                        : Convert.ToInt32(reader["ManagerId"]),
                    JoinDate = Convert.ToDateTime(reader["JoinDate"]),
                    Salary = Convert.ToDecimal(reader["Salary"]),
                    Address = reader["Address"]?.ToString(),
                    IsActive = Convert.ToBoolean(reader["IsActive"])
                });
            }

            return employees;
        }

        public async Task<EmployeeDto?> GetEmployeeByIdAsync(int employeeId)
        {
            EmployeeDto? employee = null;

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new SqlCommand(@"
                SELECT
                    EmployeeId,
                    EmployeeCode,
                    FirstName,
                    LastName,
                    Gender,
                    DateOfBirth,
                    MobileNumber,
                    Email,
                    DepartmentId,
                    ManagerId,
                    JoinDate,
                    Salary,
                    Address,
                    IsActive
                FROM Employees
                WHERE EmployeeId = @EmployeeId", connection);

            command.Parameters.AddWithValue("@EmployeeId", employeeId);

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                employee = new EmployeeDto
                {
                    EmployeeId = Convert.ToInt32(reader["EmployeeId"]),
                    EmployeeCode = reader["EmployeeCode"].ToString()!,
                    FirstName = reader["FirstName"].ToString()!,
                    LastName = reader["LastName"]?.ToString(),
                    Gender = reader["Gender"].ToString()!,
                    DateOfBirth = Convert.ToDateTime(reader["DateOfBirth"]),
                    MobileNumber = reader["MobileNumber"].ToString()!,
                    Email = reader["Email"].ToString()!,
                    DepartmentId = Convert.ToInt32(reader["DepartmentId"]),
                    ManagerId = reader["ManagerId"] == DBNull.Value
                        ? null
                        : Convert.ToInt32(reader["ManagerId"]),
                    JoinDate = Convert.ToDateTime(reader["JoinDate"]),
                    Salary = Convert.ToDecimal(reader["Salary"]),
                    Address = reader["Address"]?.ToString(),
                    IsActive = Convert.ToBoolean(reader["IsActive"])
                };
            }

            return employee;
        }
        public async Task<int> AddEmployeeAsync(EmployeeDto employee)
        {
            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();

            // Validate Department exists to avoid FK constraint failure
            using (SqlCommand check = new SqlCommand("SELECT COUNT(1) FROM Departments WHERE DepartmentId = @DepartmentId", connection))
            {
                check.Parameters.AddWithValue("@DepartmentId", employee.DepartmentId);
                var existsObj = await check.ExecuteScalarAsync();
                var exists = existsObj == null ? 0 : Convert.ToInt32(existsObj);
                if (exists == 0)
                {
                    return -1; // sentinel for missing department
                }
            }

            using SqlCommand command = new SqlCommand("sp_AddEmployee", connection);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.AddWithValue("@EmployeeCode", employee.EmployeeCode);
            command.Parameters.AddWithValue("@FirstName", employee.FirstName);
            command.Parameters.AddWithValue("@LastName", (object?)employee.LastName ?? DBNull.Value);
            command.Parameters.AddWithValue("@Gender", employee.Gender);
            command.Parameters.AddWithValue("@DateOfBirth", employee.DateOfBirth);
            command.Parameters.AddWithValue("@MobileNumber", employee.MobileNumber);
            command.Parameters.AddWithValue("@Email", employee.Email);
            command.Parameters.AddWithValue("@DepartmentId", employee.DepartmentId);
            command.Parameters.AddWithValue("@ManagerId", (object?)employee.ManagerId ?? DBNull.Value);
            command.Parameters.AddWithValue("@JoinDate", employee.JoinDate);
            command.Parameters.AddWithValue("@Salary", employee.Salary);
            command.Parameters.AddWithValue("@Address", (object?)employee.Address ?? DBNull.Value);

            try
            {
                return await command.ExecuteNonQueryAsync();
            }
            catch (SqlException)
            {
                // In case the FK still fails for unexpected reasons, return 0 for controller to map
                return 0;
            }
        }

        public async Task<int> UpdateEmployeeAsync(EmployeeDto employee)
        {
            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new SqlCommand("sp_UpdateEmployee", connection);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.AddWithValue("@EmployeeId", employee.EmployeeId);
            command.Parameters.AddWithValue("@EmployeeCode", employee.EmployeeCode);
            command.Parameters.AddWithValue("@FirstName", employee.FirstName);
            command.Parameters.AddWithValue("@LastName", (object?)employee.LastName ?? DBNull.Value);
            command.Parameters.AddWithValue("@Gender", employee.Gender);
            command.Parameters.AddWithValue("@DateOfBirth", employee.DateOfBirth);
            command.Parameters.AddWithValue("@MobileNumber", employee.MobileNumber);
            command.Parameters.AddWithValue("@Email", employee.Email);
            command.Parameters.AddWithValue("@DepartmentId", employee.DepartmentId);
            command.Parameters.AddWithValue("@ManagerId", (object?)employee.ManagerId ?? DBNull.Value);
            command.Parameters.AddWithValue("@JoinDate", employee.JoinDate);
            command.Parameters.AddWithValue("@Salary", employee.Salary);
            command.Parameters.AddWithValue("@Address", (object?)employee.Address ?? DBNull.Value);

            return await command.ExecuteNonQueryAsync();
        }

        public async Task<int> DeleteEmployeeAsync(int employeeId)
        {
            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new SqlCommand("sp_DeleteEmployee", connection);

            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.AddWithValue("@EmployeeId", employeeId);

            return await command.ExecuteNonQueryAsync();
        }

        public async Task<IEnumerable<EmployeeDto>> SearchEmployeesAsync(string? employeeName, int? departmentId)
        {
            List<EmployeeDto> employees = new();

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new SqlCommand(@"
                SELECT
                    EmployeeId,
                    EmployeeCode,
                    FirstName,
                    LastName,
                    Gender,
                    MobileNumber,
                    Email,
                    DepartmentId,
                    JoinDate,
                    Salary,
                    IsActive
                FROM Employees
                WHERE (@EmployeeName IS NULL OR FirstName LIKE '%' + @EmployeeName + '%' OR LastName LIKE '%' + @EmployeeName + '%')
                  AND (@DepartmentId IS NULL OR DepartmentId = @DepartmentId)", connection);

            command.Parameters.AddWithValue("@EmployeeName",
                string.IsNullOrWhiteSpace(employeeName) ? DBNull.Value : employeeName);

            command.Parameters.AddWithValue("@DepartmentId",
                departmentId.HasValue ? departmentId.Value : DBNull.Value);

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                employees.Add(new EmployeeDto
                {
                    EmployeeId = Convert.ToInt32(reader["EmployeeId"]),
                    EmployeeCode = reader["EmployeeCode"].ToString()!,
                    FirstName = reader["FirstName"].ToString()!,
                    LastName = reader["LastName"]?.ToString(),
                    Gender = reader["Gender"].ToString()!,
                    MobileNumber = reader["MobileNumber"].ToString()!,
                    Email = reader["Email"].ToString()!,
                    DepartmentId = Convert.ToInt32(reader["DepartmentId"]),
                    JoinDate = Convert.ToDateTime(reader["JoinDate"]),
                    Salary = Convert.ToDecimal(reader["Salary"]),
                    IsActive = Convert.ToBoolean(reader["IsActive"])
                });
            }

            return employees;
        }

        public async Task<IEnumerable<EmployeeDto>> GetEmployeesByDepartmentAsync(int departmentId)
        {
            List<EmployeeDto> employees = new();

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new SqlCommand(@"
                SELECT
                    EmployeeId,
                    EmployeeCode,
                    FirstName,
                    LastName,
                    Email,
                    MobileNumber
                FROM Employees
                WHERE DepartmentId = @DepartmentId", connection);

            command.Parameters.AddWithValue("@DepartmentId", departmentId);

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                employees.Add(new EmployeeDto
                {
                    EmployeeId = Convert.ToInt32(reader["EmployeeId"]),
                    EmployeeCode = reader["EmployeeCode"].ToString()!,
                    FirstName = reader["FirstName"].ToString()!,
                    LastName = reader["LastName"]?.ToString(),
                    Email = reader["Email"].ToString()!,
                    MobileNumber = reader["MobileNumber"].ToString()!
                });
            }

            return employees;
        }

        public async Task<int> GetEmployeeCountAsync()
        {
            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new SqlCommand("SELECT COUNT(1) FROM Employees", connection);

            object? result = await command.ExecuteScalarAsync();

            return result == null ? 0 : Convert.ToInt32(result);
        }

        public async Task<int> GetActiveEmployeeCountAsync()
        {
            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new SqlCommand("SELECT COUNT(1) FROM Employees WHERE IsActive = 1", connection);

            object? result = await command.ExecuteScalarAsync();

            return result == null ? 0 : Convert.ToInt32(result);
        }
    }
}