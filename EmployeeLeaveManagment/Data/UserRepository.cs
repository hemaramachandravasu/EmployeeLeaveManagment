using EmployeeLeaveManagment.Models;
using Microsoft.Data.SqlClient;

namespace EmployeeLeaveManagment.Data;

public class UserRepository : IUserRepository
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public UserRepository(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<User?> GetByUserNameAsync(string userName)
    {
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync(applySessionContext: false);
        await using SqlCommand command = new("""
            SELECT u.UserId, u.UserName, u.PasswordHash, u.Email, u.RoleId, u.EmployeeId,
                   u.IsActive, u.CreatedDate, u.ModifiedDate, r.RoleName,
                   e.DepartmentId
            FROM dbo.Users u
            INNER JOIN dbo.Roles r ON r.RoleId = u.RoleId
            LEFT JOIN dbo.Employees e ON e.EmployeeId = u.EmployeeId
            WHERE u.UserName = @UserName AND u.IsActive = 1 AND r.IsActive = 1
            """, connection);

        command.Parameters.AddWithValue("@UserName", userName);

        await using SqlDataReader reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
            return null;

        return new User
        {
            UserId = Convert.ToInt32(reader["UserId"]),
            UserName = reader["UserName"].ToString()!,
            PasswordHash = reader["PasswordHash"].ToString()!,
            Email = reader["Email"].ToString()!,
            RoleId = Convert.ToInt32(reader["RoleId"]),
            EmployeeId = reader["EmployeeId"] == DBNull.Value ? null : Convert.ToInt32(reader["EmployeeId"]),
            DepartmentId = reader["DepartmentId"] == DBNull.Value ? null : Convert.ToInt32(reader["DepartmentId"]),
            IsActive = Convert.ToBoolean(reader["IsActive"]),
            CreatedDate = Convert.ToDateTime(reader["CreatedDate"]),
            ModifiedDate = reader["ModifiedDate"] == DBNull.Value ? null : Convert.ToDateTime(reader["ModifiedDate"]),
            RoleName = reader["RoleName"].ToString()!
        };
    }
}
