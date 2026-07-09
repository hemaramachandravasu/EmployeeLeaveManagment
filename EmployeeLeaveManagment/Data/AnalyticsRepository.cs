using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using Microsoft.Data.SqlClient;
using System.Data;

namespace EmployeeLeaveManagment.Data
{
    public class AnalyticsRepository : IAnalyticsRepository
    {
        private readonly ISqlConnectionFactory _connectionFactory;

        public AnalyticsRepository(ISqlConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        public async Task<IEnumerable<AnalyticsDto>> GetLeaveTrendAnalysisAsync(int? year = null)
        {
            List<AnalyticsDto> analytics = new();

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();

            using SqlCommand command = new("sp_LeaveTrendAnalysis", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.AddWithValue("@Year", (object?)year ?? DBNull.Value);

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            int ordMonth, ordYear, ordTotalLeaves, ordTotalDays;
            
            while (await reader.ReadAsync())
            {
                ordMonth = TryGetOrdinal(reader, "Month");
                ordYear = TryGetOrdinal(reader, "Year");
                ordTotalLeaves = TryGetOrdinal(reader, "TotalLeaves");
                ordTotalDays = TryGetOrdinal(reader, "TotalDays");

                analytics.Add(new AnalyticsDto
                {
                    Month = ordMonth >= 0 && !reader.IsDBNull(ordMonth) ? Convert.ToInt32(reader.GetValue(ordMonth)) : 0,
                    Year = ordYear >= 0 && !reader.IsDBNull(ordYear) ? Convert.ToInt32(reader.GetValue(ordYear)) : (year ?? 0),
                    TotalLeaves = ordTotalLeaves >= 0 && !reader.IsDBNull(ordTotalLeaves) ? Convert.ToInt32(reader.GetValue(ordTotalLeaves)) : 0,
                    TotalDays = ordTotalDays >= 0 && !reader.IsDBNull(ordTotalDays) ? Convert.ToInt32(reader.GetValue(ordTotalDays)) : 0
                });
            }

            return analytics;
        }

        public async Task<IEnumerable<AnalyticsDto>> GetDepartmentComparisonAsync(int? year = null)
        {
            List<AnalyticsDto> analytics = new();

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();

            using SqlCommand command = new("sp_DepartmentComparison", connection);
            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.AddWithValue("@Year", (object?)year ?? DBNull.Value);

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            int ordDeptName = -1, ordTotalLeaves = -1, ordTotalDays = -1;
            while (await reader.ReadAsync())
            {
                ordDeptName = TryGetOrdinal(reader, "DepartmentName");
                ordTotalLeaves = TryGetOrdinal(reader, "TotalLeaves");
                ordTotalDays = TryGetOrdinal(reader, "TotalDays");

                analytics.Add(new AnalyticsDto
                {
                    DepartmentName = ordDeptName >= 0 && !reader.IsDBNull(ordDeptName) ? reader.GetString(ordDeptName) : null,
                    TotalLeaves = ordTotalLeaves >= 0 && !reader.IsDBNull(ordTotalLeaves) ? Convert.ToInt32(reader.GetValue(ordTotalLeaves)) : 0,
                    TotalDays = ordTotalDays >= 0 && !reader.IsDBNull(ordTotalDays) ? Convert.ToInt32(reader.GetValue(ordTotalDays)) : 0
                });
            }

            return analytics;
        }
        public async Task<IEnumerable<AnalyticsDto>> GetFrequentLeavePatternAsync()
        {
            List<AnalyticsDto> analytics = new();

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new("sp_FrequentLeavePattern", connection);

            command.CommandType = CommandType.StoredProcedure;

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                int ordEmpCode = TryGetOrdinal(reader, "EmployeeCode");
                int ordEmpName = TryGetOrdinal(reader, "EmployeeName");
                int ordDept = TryGetOrdinal(reader, "DepartmentName");
                int ordTotalLeaves = TryGetOrdinal(reader, "TotalLeaves");
                int ordTotalLeaveDays = TryGetOrdinal(reader, "TotalLeaveDays");
                int ordAvgLeaveDays = TryGetOrdinal(reader, "AverageLeaveDays");

                analytics.Add(new AnalyticsDto
                {
                    EmployeeCode = ordEmpCode >= 0 && !reader.IsDBNull(ordEmpCode) ? reader.GetString(ordEmpCode) : null,
                    EmployeeName = ordEmpName >= 0 && !reader.IsDBNull(ordEmpName) ? reader.GetString(ordEmpName) : null,
                    DepartmentName = ordDept >= 0 && !reader.IsDBNull(ordDept) ? reader.GetString(ordDept) : null,
                    TotalLeaves = ordTotalLeaves >= 0 && !reader.IsDBNull(ordTotalLeaves) ? Convert.ToInt32(reader.GetValue(ordTotalLeaves)) : 0,
                    TotalDays = ordTotalLeaveDays >= 0 && !reader.IsDBNull(ordTotalLeaveDays) ? Convert.ToInt32(reader.GetValue(ordTotalLeaveDays)) : 0,
                    AverageLeaveDays = ordAvgLeaveDays >= 0 && !reader.IsDBNull(ordAvgLeaveDays) ? Convert.ToDecimal(reader.GetValue(ordAvgLeaveDays)) : 0M
                });
            }

            return analytics;
        }

        public async Task<IEnumerable<AnalyticsDto>> GetForecastLeaveUtilizationAsync()
        {
            List<AnalyticsDto> analytics = new();

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new("sp_ForecastLeaveUtilization", connection);

            command.CommandType = CommandType.StoredProcedure;

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                int ordDept = TryGetOrdinal(reader, "DepartmentName");
                int ordLeaveType = TryGetOrdinal(reader, "LeaveTypeName");
                int ordForecastCount = TryGetOrdinal(reader, "ForecastLeaveCount");
                int ordForecastAvg = TryGetOrdinal(reader, "ForecastAverageDays");

                analytics.Add(new AnalyticsDto
                {
                    DepartmentName = ordDept >= 0 && !reader.IsDBNull(ordDept) ? reader.GetString(ordDept) : null,
                    LeaveType = ordLeaveType >= 0 && !reader.IsDBNull(ordLeaveType) ? reader.GetString(ordLeaveType) : null,
                    TotalLeaves = ordForecastCount >= 0 && !reader.IsDBNull(ordForecastCount) ? Convert.ToInt32(reader.GetValue(ordForecastCount)) : 0,
                    AverageLeaveDays = ordForecastAvg >= 0 && !reader.IsDBNull(ordForecastAvg) ? Convert.ToDecimal(reader.GetValue(ordForecastAvg)) : 0M
                });
            }

            return analytics;
        }
        private int TryGetOrdinal(SqlDataReader reader, string name)
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
}