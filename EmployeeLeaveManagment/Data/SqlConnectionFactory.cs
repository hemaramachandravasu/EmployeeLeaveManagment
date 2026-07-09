using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.Data.SqlClient;

namespace EmployeeLeaveManagment.Data;

public interface ISqlConnectionFactory
{
    Task<SqlConnection> CreateOpenConnectionAsync(bool applySessionContext = true, CancellationToken cancellationToken = default);

    Task<SqlConnection> CreateReportViewerConnectionAsync(CancellationToken cancellationToken = default);

    Task<SqlConnection> CreateDataWarehouseConnectionAsync(CancellationToken cancellationToken = default);
}

/// <summary>
/// Opens SQL connections and applies SESSION_CONTEXT for Row-Level Security policies.
/// </summary>
public class SqlConnectionFactory : ISqlConnectionFactory
{
    private readonly string _connectionString;
    private readonly string _reportViewerConnectionString;
    private readonly string _dataWarehouseConnectionString;
    private readonly IHttpContextAccessor _httpContextAccessor;

    public SqlConnectionFactory(IConfiguration configuration, IHttpContextAccessor httpContextAccessor)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection")!;
        // Optional least-privilege login for reporting; falls back to the default connection
        // when a dedicated ReportViewer connection is not configured.
        _reportViewerConnectionString =
            configuration.GetConnectionString("ReportViewerConnection") ?? _connectionString;
        _dataWarehouseConnectionString =
            configuration.GetConnectionString("DataWarehouseConnection")
            ?? configuration.GetConnectionString("DefaultConnection")!.Replace("EmployeeLeaveDb", "EmployeeLeaveDW");
        _httpContextAccessor = httpContextAccessor;
    }

    public async Task<SqlConnection> CreateOpenConnectionAsync(bool applySessionContext = true, CancellationToken cancellationToken = default)
    {
        SqlConnection connection = new(_connectionString);
        await connection.OpenAsync(cancellationToken);

        if (applySessionContext)
            await ApplySessionContextAsync(connection, cancellationToken);

        return connection;
    }

    public async Task<SqlConnection> CreateReportViewerConnectionAsync(CancellationToken cancellationToken = default)
    {
        SqlConnection connection = new(_reportViewerConnectionString);
        await connection.OpenAsync(cancellationToken);
        await ApplySessionContextAsync(connection, cancellationToken);
        return connection;
    }

    public async Task<SqlConnection> CreateDataWarehouseConnectionAsync(CancellationToken cancellationToken = default)
    {
        SqlConnection connection = new(_dataWarehouseConnectionString);
        await connection.OpenAsync(cancellationToken);
        return connection;
    }

    public static async Task ApplySessionContextAsync(SqlConnection connection, ClaimsPrincipal? user, CancellationToken cancellationToken = default)
    {
        string roleName = user?.FindFirst(ClaimTypes.Role)?.Value ?? "Admin";
        string? employeeId = user?.FindFirst("EmployeeId")?.Value;
        string? departmentId = user?.FindFirst("DepartmentId")?.Value;

        await using SqlCommand command = connection.CreateCommand();
        command.CommandText = """
            EXEC sp_set_session_context @key = N'RoleName', @value = @RoleName;
            EXEC sp_set_session_context @key = N'EmployeeId', @value = @EmployeeId;
            EXEC sp_set_session_context @key = N'DepartmentId', @value = @DepartmentId;
            """;
        command.Parameters.AddWithValue("@RoleName", roleName);
        command.Parameters.AddWithValue("@EmployeeId", (object?)employeeId ?? DBNull.Value);
        command.Parameters.AddWithValue("@DepartmentId", (object?)departmentId ?? DBNull.Value);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private Task ApplySessionContextAsync(SqlConnection connection, CancellationToken cancellationToken)
    {
        ClaimsPrincipal? user = _httpContextAccessor.HttpContext?.User;
        return ApplySessionContextAsync(connection, user, cancellationToken);
    }
}
