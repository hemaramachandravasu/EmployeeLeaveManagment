using EmployeeLeaveManagment.DTOs;
using Microsoft.Data.SqlClient;
using System.Data;

namespace EmployeeLeaveManagment.Data;

public class AnalyticsRepository : IAnalyticsRepository
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public AnalyticsRepository(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IEnumerable<LeaveTrendDto>> GetLeaveTrendAnalysisAsync(int? year = null)
    {
        List<LeaveTrendDto> analytics = new();
        int resolvedYear = year ?? DateTime.UtcNow.Year;

        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_LeaveTrendAnalysis", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddWithValue("@Year", resolvedYear);

        await using SqlDataReader reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            analytics.Add(new LeaveTrendDto
            {
                Year = GetInt(reader, "Year", resolvedYear),
                Month = GetInt(reader, "Month"),
                TotalLeaves = GetInt(reader, "TotalLeaves"),
                TotalDays = GetInt(reader, "TotalDays"),
                MonthOverMonthChangePercent = GetNullableDecimal(reader, "MonthOverMonthChangePercent")
            });
        }

        return analytics;
    }

    public async Task<IEnumerable<DepartmentComparisonDto>> GetDepartmentComparisonAsync(int? year = null)
    {
        List<DepartmentComparisonDto> analytics = new();
        int resolvedYear = year ?? DateTime.UtcNow.Year;

        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_DepartmentComparison", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddWithValue("@Year", resolvedYear);

        await using SqlDataReader reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            analytics.Add(new DepartmentComparisonDto
            {
                Year = GetInt(reader, "Year", resolvedYear),
                DepartmentName = GetString(reader, "DepartmentName") ?? string.Empty,
                TotalLeaves = GetInt(reader, "TotalLeaves"),
                TotalDays = GetInt(reader, "TotalDays"),
                AverageLeaveDays = GetDecimal(reader, "AverageLeaveDays")
            });
        }

        return analytics;
    }

    public async Task<IEnumerable<FrequentLeavePatternDto>> GetFrequentLeavePatternAsync()
    {
        List<FrequentLeavePatternDto> analytics = new();

        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_FrequentLeavePattern", connection)
        {
            CommandType = CommandType.StoredProcedure
        };

        await using SqlDataReader reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            analytics.Add(new FrequentLeavePatternDto
            {
                EmployeeCode = GetString(reader, "EmployeeCode") ?? string.Empty,
                EmployeeName = GetString(reader, "EmployeeName") ?? string.Empty,
                DepartmentName = GetString(reader, "DepartmentName") ?? string.Empty,
                TotalLeaves = GetInt(reader, "TotalLeaves"),
                TotalDays = GetInt(reader, "TotalLeaveDays", GetInt(reader, "TotalDays")),
                AverageLeaveDays = GetDecimal(reader, "AverageLeaveDays")
            });
        }

        return analytics;
    }

    public async Task<IEnumerable<ForecastLeaveUtilizationDto>> GetForecastLeaveUtilizationAsync()
    {
        List<ForecastLeaveUtilizationDto> analytics = new();

        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_ForecastLeaveUtilization", connection)
        {
            CommandType = CommandType.StoredProcedure
        };

        await using SqlDataReader reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            analytics.Add(new ForecastLeaveUtilizationDto
            {
                DepartmentName = GetString(reader, "DepartmentName") ?? string.Empty,
                LeaveType = GetString(reader, "LeaveTypeName") ?? GetString(reader, "LeaveType") ?? string.Empty,
                ForecastLeaveCount = GetInt(reader, "ForecastLeaveCount"),
                ForecastAverageDays = GetDecimal(reader, "ForecastAverageDays")
            });
        }

        return analytics;
    }

    private static int GetInt(SqlDataReader reader, string column, int fallback = 0)
    {
        int ordinal = TryGetOrdinal(reader, column);
        if (ordinal < 0 || reader.IsDBNull(ordinal))
            return fallback;
        return Convert.ToInt32(reader.GetValue(ordinal));
    }

    private static decimal GetDecimal(SqlDataReader reader, string column, decimal fallback = 0M)
    {
        int ordinal = TryGetOrdinal(reader, column);
        if (ordinal < 0 || reader.IsDBNull(ordinal))
            return fallback;
        return Convert.ToDecimal(reader.GetValue(ordinal));
    }

    private static decimal? GetNullableDecimal(SqlDataReader reader, string column)
    {
        int ordinal = TryGetOrdinal(reader, column);
        if (ordinal < 0 || reader.IsDBNull(ordinal))
            return null;
        return Convert.ToDecimal(reader.GetValue(ordinal));
    }

    private static string? GetString(SqlDataReader reader, string column)
    {
        int ordinal = TryGetOrdinal(reader, column);
        if (ordinal < 0 || reader.IsDBNull(ordinal))
            return null;
        return reader.GetString(ordinal);
    }

    private static int TryGetOrdinal(SqlDataReader reader, string name)
    {
        try
        {
            return reader.GetOrdinal(name);
        }
        catch (IndexOutOfRangeException)
        {
            return -1;
        }
    }
}
