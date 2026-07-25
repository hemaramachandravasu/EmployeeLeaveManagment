using EmployeeLeaveManagment.DTOs;
using Microsoft.Data.SqlClient;
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
            await using SqlCommand command = new(@"
                SELECT
                    EmployeeId, EmployeeCode, FirstName, LastName, Gender, DateOfBirth,
                    MobileNumber, Email, DepartmentId, ManagerId, JoinDate, Salary, Address, IsActive
                FROM Employees
                ORDER BY EmployeeId", connection);

            await using SqlDataReader reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
                employees.Add(MapEmployee(reader));

            return employees;
        }

        public async Task<EmployeeDto?> GetEmployeeByIdAsync(int employeeId)
        {
            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            await using SqlCommand command = new(@"
                SELECT
                    EmployeeId, EmployeeCode, FirstName, LastName, Gender, DateOfBirth,
                    MobileNumber, Email, DepartmentId, ManagerId, JoinDate, Salary, Address, IsActive
                FROM Employees
                WHERE EmployeeId = @EmployeeId", connection);

            command.Parameters.AddWithValue("@EmployeeId", employeeId);

            await using SqlDataReader reader = await command.ExecuteReaderAsync();
            if (!await reader.ReadAsync())
                return null;

            return MapEmployee(reader);
        }

        public async Task<int> AddEmployeeAsync(EmployeeDto employee)
        {
            try
            {
                await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
                await using SqlCommand command = new("sp_AddEmployee", connection)
                {
                    CommandType = CommandType.StoredProcedure
                };

                AddEmployeeParameters(command, employee, includeEmployeeId: false);

                SqlParameter outputId = new("@NewEmployeeId", SqlDbType.Int)
                {
                    Direction = ParameterDirection.Output
                };
                command.Parameters.Add(outputId);

                SqlParameter returnValue = AddReturnValue(command);
                await command.ExecuteNonQueryAsync();

                int code = ReadReturnValue(returnValue);
                if (code < 0)
                    return code;

                if (outputId.Value != DBNull.Value && outputId.Value != null)
                {
                    int newId = Convert.ToInt32(outputId.Value);
                    if (newId > 0)
                        return newId;
                }

                return code > 0 ? code : 0;
            }
            catch (SqlException ex) when (ex.Number is 2627 or 2601)
            {
                return -2;
            }
            catch (SqlException ex) when (ex.Number == 547)
            {
                return -1;
            }
        }

        public async Task<int> UpdateEmployeeAsync(EmployeeDto employee)
        {
            try
            {
                await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
                await using SqlCommand command = new("sp_UpdateEmployee", connection)
                {
                    CommandType = CommandType.StoredProcedure
                };

                AddEmployeeParameters(command, employee, includeEmployeeId: true);
                command.Parameters.AddWithValue("@IsActive", employee.IsActive);

                SqlParameter returnValue = AddReturnValue(command);
                await command.ExecuteNonQueryAsync();
                return ReadReturnValue(returnValue);
            }
            catch (SqlException ex) when (ex.Number is 2627 or 2601)
            {
                return -3;
            }
            catch (SqlException ex) when (ex.Number == 547)
            {
                return -2;
            }
        }

        public async Task<int> DeleteEmployeeAsync(int employeeId)
        {
            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            await using SqlCommand command = new("sp_DeleteEmployee", connection)
            {
                CommandType = CommandType.StoredProcedure
            };
            command.Parameters.AddWithValue("@EmployeeId", employeeId);

            SqlParameter returnValue = AddReturnValue(command);
            await command.ExecuteNonQueryAsync();
            return ReadReturnValue(returnValue);
        }

        public async Task<IEnumerable<EmployeeDto>> SearchEmployeesAsync(string? employeeName, int? departmentId)
        {
            List<EmployeeDto> employees = new();

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            await using SqlCommand command = new(@"
                SELECT
                    EmployeeId, EmployeeCode, FirstName, LastName, Gender, DateOfBirth,
                    MobileNumber, Email, DepartmentId, ManagerId, JoinDate, Salary, Address, IsActive
                FROM Employees
                WHERE (@EmployeeName IS NULL
                       OR FirstName LIKE '%' + @EmployeeName + '%'
                       OR LastName LIKE '%' + @EmployeeName + '%'
                       OR EmployeeCode LIKE '%' + @EmployeeName + '%')
                  AND (@DepartmentId IS NULL OR DepartmentId = @DepartmentId)
                ORDER BY EmployeeId", connection);

            command.Parameters.AddWithValue("@EmployeeName",
                string.IsNullOrWhiteSpace(employeeName) ? DBNull.Value : employeeName.Trim());
            command.Parameters.AddWithValue("@DepartmentId",
                departmentId.HasValue ? departmentId.Value : DBNull.Value);

            await using SqlDataReader reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
                employees.Add(MapEmployee(reader));

            return employees;
        }

        public async Task<IEnumerable<EmployeeDto>> GetEmployeesByDepartmentAsync(int departmentId)
        {
            List<EmployeeDto> employees = new();

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            await using SqlCommand command = new(@"
                SELECT
                    EmployeeId, EmployeeCode, FirstName, LastName, Gender, DateOfBirth,
                    MobileNumber, Email, DepartmentId, ManagerId, JoinDate, Salary, Address, IsActive
                FROM Employees
                WHERE DepartmentId = @DepartmentId
                ORDER BY EmployeeId", connection);

            command.Parameters.AddWithValue("@DepartmentId", departmentId);

            await using SqlDataReader reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
                employees.Add(MapEmployee(reader));

            return employees;
        }

        public async Task<int> GetEmployeeCountAsync()
        {
            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            await using SqlCommand command = new("SELECT COUNT(1) FROM Employees", connection);
            object? result = await command.ExecuteScalarAsync();
            return result == null ? 0 : Convert.ToInt32(result);
        }

        public async Task<int> GetActiveEmployeeCountAsync()
        {
            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            await using SqlCommand command = new("SELECT COUNT(1) FROM Employees WHERE IsActive = 1", connection);
            object? result = await command.ExecuteScalarAsync();
            return result == null ? 0 : Convert.ToInt32(result);
        }

        private static void AddEmployeeParameters(SqlCommand command, EmployeeDto employee, bool includeEmployeeId)
        {
            if (includeEmployeeId)
                command.Parameters.AddWithValue("@EmployeeId", employee.EmployeeId);

            command.Parameters.AddWithValue("@EmployeeCode", employee.EmployeeCode.Trim());
            command.Parameters.AddWithValue("@FirstName", employee.FirstName.Trim());
            command.Parameters.AddWithValue("@LastName", (object?)employee.LastName?.Trim() ?? DBNull.Value);
            command.Parameters.AddWithValue("@Gender", employee.Gender.Trim());
            command.Parameters.AddWithValue("@DateOfBirth", employee.DateOfBirth.Date);
            command.Parameters.AddWithValue("@MobileNumber", employee.MobileNumber.Trim());
            command.Parameters.AddWithValue("@Email", employee.Email.Trim());
            command.Parameters.AddWithValue("@DepartmentId", employee.DepartmentId);
            command.Parameters.AddWithValue("@ManagerId", (object?)employee.ManagerId ?? DBNull.Value);
            command.Parameters.AddWithValue("@JoinDate", employee.JoinDate.Date);
            command.Parameters.AddWithValue("@Salary", employee.Salary);
            command.Parameters.AddWithValue("@Address", (object?)employee.Address?.Trim() ?? DBNull.Value);
        }

        private static SqlParameter AddReturnValue(SqlCommand command)
        {
            SqlParameter returnValue = new("@ReturnValue", SqlDbType.Int)
            {
                Direction = ParameterDirection.ReturnValue
            };
            command.Parameters.Add(returnValue);
            return returnValue;
        }

        private static int ReadReturnValue(SqlParameter returnValue)
        {
            if (returnValue.Value == null || returnValue.Value == DBNull.Value)
                return 0;

            return Convert.ToInt32(returnValue.Value);
        }

        private static EmployeeDto MapEmployee(SqlDataReader reader)
        {
            return new EmployeeDto
            {
                EmployeeId = Convert.ToInt32(reader["EmployeeId"]),
                EmployeeCode = reader["EmployeeCode"].ToString()!,
                FirstName = reader["FirstName"].ToString()!,
                LastName = reader["LastName"] == DBNull.Value ? null : reader["LastName"].ToString(),
                Gender = reader["Gender"].ToString()!,
                DateOfBirth = Convert.ToDateTime(reader["DateOfBirth"]),
                MobileNumber = reader["MobileNumber"].ToString()!,
                Email = reader["Email"].ToString()!,
                DepartmentId = Convert.ToInt32(reader["DepartmentId"]),
                ManagerId = reader["ManagerId"] == DBNull.Value ? null : Convert.ToInt32(reader["ManagerId"]),
                JoinDate = Convert.ToDateTime(reader["JoinDate"]),
                Salary = Convert.ToDecimal(reader["Salary"]),
                Address = reader["Address"] == DBNull.Value ? null : reader["Address"].ToString(),
                IsActive = Convert.ToBoolean(reader["IsActive"])
            };
        }
    }
}
