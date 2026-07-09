using EmployeeLeaveManagment.DTOs;
using Microsoft.Data.SqlClient;
using System.Data;

namespace EmployeeLeaveManagment.Data;

public class DashboardRepository : IDashboardRepository
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public DashboardRepository(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<DashboardDto> GetDashboardDataAsync()
    {
        DashboardDto dashboard = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_GetDashboardData", connection) { CommandType = CommandType.StoredProcedure };
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            dashboard.TotalEmployees = Convert.ToInt32(reader["TotalEmployees"]);
            dashboard.TotalDepartments = Convert.ToInt32(reader["TotalDepartments"]);
            dashboard.TotalLeaveRequests = Convert.ToInt32(reader["TotalLeaveRequests"]);
            dashboard.PendingLeaves = Convert.ToInt32(reader["PendingLeaves"]);
            dashboard.ApprovedLeaves = Convert.ToInt32(reader["ApprovedLeaves"]);
            dashboard.RejectedLeaves = Convert.ToInt32(reader["RejectedLeaves"]);
            dashboard.TotalLeaveTypes = Convert.ToInt32(reader["TotalLeaveTypes"]);
        }

        return dashboard;
    }

    public async Task<IEnumerable<DepartmentLeaveFeedDto>> GetDepartmentLeaveCountsAsync(int? year)
    {
        List<DepartmentLeaveFeedDto> feeds = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_DepartmentComparison", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@Year", (object?)year ?? DBNull.Value);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            feeds.Add(new DepartmentLeaveFeedDto
            {
                DepartmentName = reader["DepartmentName"].ToString()!,
                TotalLeaves = Convert.ToInt32(reader["TotalLeaves"]),
                TotalDays = Convert.ToInt32(reader["TotalDays"])
            });
        }

        return feeds;
    }

    public async Task<IEnumerable<MonthlyTrendFeedDto>> GetMonthlyUtilizationTrendAsync(int? year)
    {
        List<MonthlyTrendFeedDto> feeds = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_LeaveTrendAnalysis", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@Year", (object?)year ?? DBNull.Value);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            feeds.Add(new MonthlyTrendFeedDto
            {
                Month = Convert.ToInt32(reader["Month"]),
                Year = Convert.ToInt32(reader["Year"]),
                TotalLeaves = Convert.ToInt32(reader["TotalLeaves"]),
                TotalDays = Convert.ToInt32(reader["TotalDays"])
            });
        }

        return feeds;
    }
}
