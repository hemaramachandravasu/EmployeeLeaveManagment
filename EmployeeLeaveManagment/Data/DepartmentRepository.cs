using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using Microsoft.Data.SqlClient;
using System.Data;

namespace EmployeeLeaveManagment.Data
{
    public class DepartmentRepository : IDepartmentRepository
    {
        private readonly ISqlConnectionFactory _connectionFactory;

        public DepartmentRepository(ISqlConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        public async Task<IEnumerable<DepartmentDto>> GetAllDepartmentsAsync()
        {
            List<DepartmentDto> departments = new();

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new SqlCommand(@"
                SELECT DepartmentId, DepartmentName, DepartmentCode, Description, IsActive
                FROM Departments", connection);

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                departments.Add(new DepartmentDto
                {
                    DepartmentId = Convert.ToInt32(reader["DepartmentId"]),
                    DepartmentName = reader["DepartmentName"].ToString()!,
                    DepartmentCode = reader["DepartmentCode"].ToString()!,
                    Description = reader["Description"]?.ToString(),
                    IsActive = Convert.ToBoolean(reader["IsActive"])
                });
            }

            return departments;
        }

        public async Task<DepartmentDto?> GetDepartmentByIdAsync(int departmentId)
        {
            DepartmentDto? department = null;

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new SqlCommand(@"
                SELECT DepartmentId, DepartmentName, DepartmentCode, Description, IsActive
                FROM Departments
                WHERE DepartmentId = @DepartmentId", connection);

            command.Parameters.AddWithValue("@DepartmentId", departmentId);

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                department = new DepartmentDto
                {
                    DepartmentId = Convert.ToInt32(reader["DepartmentId"]),
                    DepartmentName = reader["DepartmentName"].ToString()!,
                    DepartmentCode = reader["DepartmentCode"].ToString()!,
                    Description = reader["Description"]?.ToString(),
                    IsActive = Convert.ToBoolean(reader["IsActive"])
                };
            }

            return department;
        }

        public async Task<int> AddDepartmentAsync(DepartmentDto department)
        {
            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();

            // Prevent duplicate department by name or code
            using (SqlCommand check = new SqlCommand("SELECT COUNT(1) FROM Departments WHERE DepartmentName = @DepartmentName OR DepartmentCode = @DepartmentCode", connection))
            {
                check.Parameters.AddWithValue("@DepartmentName", department.DepartmentName);
                check.Parameters.AddWithValue("@DepartmentCode", department.DepartmentCode);
                var existsObj = await check.ExecuteScalarAsync();
                var exists = existsObj == null ? 0 : Convert.ToInt32(existsObj);
                if (exists > 0)
                {
                    return -1; // sentinel for duplicate
                }
            }

            using SqlCommand insert = new SqlCommand(@"
                INSERT INTO Departments (DepartmentName, DepartmentCode, Description, IsActive)
                VALUES (@DepartmentName, @DepartmentCode, @Description, @IsActive)", connection);

            insert.Parameters.AddWithValue("@DepartmentName", department.DepartmentName);
            insert.Parameters.AddWithValue("@DepartmentCode", department.DepartmentCode);
            insert.Parameters.AddWithValue("@Description", (object?)department.Description ?? DBNull.Value);
            insert.Parameters.AddWithValue("@IsActive", department.IsActive);

            try
            {
                return await insert.ExecuteNonQueryAsync();
            }
            catch (SqlException)
            {
                return 0;
            }
        }

        public async Task<int> UpdateDepartmentAsync(DepartmentDto department)
        {
            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new SqlCommand(@"
                UPDATE Departments
                SET DepartmentName = @DepartmentName,
                    DepartmentCode = @DepartmentCode,
                    Description = @Description,
                    IsActive = @IsActive
                WHERE DepartmentId = @DepartmentId", connection);

            command.Parameters.AddWithValue("@DepartmentId", department.DepartmentId);
            command.Parameters.AddWithValue("@DepartmentName", department.DepartmentName);
            command.Parameters.AddWithValue("@DepartmentCode", department.DepartmentCode);
            command.Parameters.AddWithValue("@Description", (object?)department.Description ?? DBNull.Value);
            command.Parameters.AddWithValue("@IsActive", department.IsActive);

            return await command.ExecuteNonQueryAsync();
        }

        public async Task<int> DeleteDepartmentAsync(int departmentId)
        {
            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();

            using SqlCommand command = new SqlCommand("DELETE FROM Departments WHERE DepartmentId = @DepartmentId", connection);
            command.Parameters.AddWithValue("@DepartmentId", departmentId);

            try
            {
                return await command.ExecuteNonQueryAsync();
            }
            catch (SqlException ex)
            {
                // SQL Server error 547 is a foreign key violation (referenced elsewhere)
                if (ex.Number == 547)
                    return -2; // sentinel for FK constraint

                throw;
            }
        }
    }
}