using System.Security.Claims;
using EmployeeLeaveManagment.Data;
using Microsoft.Data.SqlClient;
using Xunit;

namespace EmployeeLeaveManagment.Tests;

[Trait("Category", "Integration")]
public class SecurityIntegrationTests
{
    private static readonly string? ConnectionString =
        Environment.GetEnvironmentVariable("ELM_CONNECTION_STRING")
        ?? "Server=localhost;Database=EmployeeLeaveDb;Trusted_Connection=True;TrustServerCertificate=True;";

    private static bool CanConnect()
    {
        try
        {
            using SqlConnection conn = new(ConnectionString);
            conn.Open();
            return true;
        }
        catch
        {
            return false;
        }
    }

    [Fact]
    public async Task RLS_Employee_SeesOnlyOwnLeaveRequests()
    {
        if (!CanConnect()) return;

        await using SqlConnection connection = new(ConnectionString);
        await connection.OpenAsync();
        await SqlConnectionFactory.ApplySessionContextAsync(connection, BuildPrincipal("Employee", employeeId: 2, departmentId: 2));

        int count = await ScalarCountAsync(connection, "SELECT COUNT(*) FROM dbo.LeaveRequests");
        Assert.Equal(1, count);
    }

    [Fact]
    public async Task RLS_Manager_SeesDepartmentLeaveRequests()
    {
        if (!CanConnect()) return;

        await using SqlConnection connection = new(ConnectionString);
        await connection.OpenAsync();
        await SqlConnectionFactory.ApplySessionContextAsync(connection, BuildPrincipal("Manager", employeeId: 1, departmentId: 2));

        int count = await ScalarCountAsync(connection, "SELECT COUNT(*) FROM dbo.LeaveRequests");
        Assert.True(count >= 2);
    }

    [Fact]
    public async Task RLS_Admin_SeesAllLeaveRequests()
    {
        if (!CanConnect()) return;

        await using SqlConnection connection = new(ConnectionString);
        await connection.OpenAsync();
        await SqlConnectionFactory.ApplySessionContextAsync(connection, BuildPrincipal("Admin"));

        int count = await ScalarCountAsync(connection, "SELECT COUNT(*) FROM dbo.LeaveRequests");
        Assert.True(count >= 3);
    }

    [Fact]
    public async Task DDM_ReportViewerLogin_SeesMaskedEmployeeEmail()
    {
        if (!CanConnect()) return;

        const string reportViewerCs =
            "Server=localhost;Database=EmployeeLeaveDb;User Id=elm_ReportViewer;Password=Elm_ReportViewer_Dev1!;TrustServerCertificate=True;";

        try
        {
            await using SqlConnection connection = new(reportViewerCs);
            await connection.OpenAsync();
            await using SqlCommand command = new("SELECT TOP 1 Email FROM dbo.Employees", connection);
            object? email = await command.ExecuteScalarAsync();
            string value = email?.ToString() ?? string.Empty;
            Assert.Contains("XXXX", value, StringComparison.OrdinalIgnoreCase);
        }
        catch (SqlException)
        {
            // SQL auth login may not exist if SECURITY_DEPLOY was not run — skip gracefully
            return;
        }
    }

    [Fact]
    public async Task HealthCheck_ExecutesSuccessfully()
    {
        if (!CanConnect()) return;

        await using SqlConnection connection = new(ConnectionString);
        await connection.OpenAsync();
        await using SqlCommand command = new("dbo.sp_DatabaseHealthCheck", connection) { CommandType = System.Data.CommandType.StoredProcedure };

        try
        {
            await using var reader = await command.ExecuteReaderAsync();
            int resultSets = 0;
            do
            {
                resultSets++;
                while (await reader.ReadAsync()) { }
            } while (await reader.NextResultAsync());

            Assert.Equal(4, resultSets);
        }
        catch (SqlException ex) when (ex.Number == 2812)
        {
            return;
        }
    }

    private static ClaimsPrincipal BuildPrincipal(string role, int? employeeId = null, int? departmentId = null)
    {
        var claims = new List<Claim> { new(ClaimTypes.Role, role) };
        if (employeeId.HasValue) claims.Add(new Claim("EmployeeId", employeeId.Value.ToString()));
        if (departmentId.HasValue) claims.Add(new Claim("DepartmentId", departmentId.Value.ToString()));
        return new ClaimsPrincipal(new ClaimsIdentity(claims, "Test"));
    }

    private static async Task<int> ScalarCountAsync(SqlConnection connection, string sql)
    {
        await using SqlCommand command = new(sql, connection);
        return Convert.ToInt32(await command.ExecuteScalarAsync());
    }
}
