using EmployeeLeaveManagment.DTOs;
using Microsoft.Data.SqlClient;
using System.Data;

namespace EmployeeLeaveManagment.Data;

public class LeaveRepository : ILeaveRepository
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public LeaveRepository(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IEnumerable<LeaveRequestDto>> GetAllLeavesAsync()
    {
        List<LeaveRequestDto> leaves = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_GetAllLeaveRequests", connection) { CommandType = CommandType.StoredProcedure };
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            leaves.Add(MapLeaveRequest(reader));
        }

        return leaves;
    }

    public async Task<LeaveRequestDto?> GetLeaveByIdAsync(int leaveRequestId)
    {
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_GetLeaveById", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@LeaveRequestId", leaveRequestId);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        if (!await reader.ReadAsync())
            return null;

        return MapLeaveRequest(reader);
    }

    public async Task<int> ApplyLeaveAsync(LeaveRequestDto leaveRequest)
    {
        try
        {
            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            await using SqlCommand command = new("sp_ApplyLeave", connection) { CommandType = CommandType.StoredProcedure };

            command.Parameters.AddWithValue("@EmployeeId", leaveRequest.EmployeeId);
            command.Parameters.AddWithValue("@LeaveTypeId", leaveRequest.LeaveTypeId);
            command.Parameters.AddWithValue("@StartDate", leaveRequest.StartDate.Date);
            command.Parameters.AddWithValue("@EndDate", leaveRequest.EndDate.Date);
            command.Parameters.AddWithValue("@Reason", leaveRequest.Reason.Trim());

            SqlParameter outputIdParameter = new("@NewLeaveRequestId", SqlDbType.Int)
            {
                Direction = ParameterDirection.Output
            };
            command.Parameters.Add(outputIdParameter);

            SqlParameter returnValueParameter = new("@ReturnValue", SqlDbType.Int)
            {
                Direction = ParameterDirection.ReturnValue
            };
            command.Parameters.Add(returnValueParameter);

            await command.ExecuteNonQueryAsync();

            int returnValue = returnValueParameter.Value is int rv ? rv : Convert.ToInt32(returnValueParameter.Value ?? 0);
            if (returnValue < 0)
                return returnValue;

            if (outputIdParameter.Value != DBNull.Value && outputIdParameter.Value != null)
            {
                int outputId = Convert.ToInt32(outputIdParameter.Value);
                if (outputId > 0)
                    return outputId;
            }

            return returnValue > 0 ? returnValue : 0;
        }
        catch (SqlException ex) when (ex.Number is 547 or 515)
        {
            // FK / NOT NULL constraint — map to generic validation failure
            return 0;
        }
    }

    public async Task<int> UpdateLeaveAsync(LeaveRequestDto leaveRequest)
    {
        try
        {
            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            await using SqlCommand command = new("sp_UpdateLeave", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.AddWithValue("@LeaveRequestId", leaveRequest.LeaveRequestId);
            command.Parameters.AddWithValue("@LeaveTypeId", leaveRequest.LeaveTypeId);
            command.Parameters.AddWithValue("@StartDate", leaveRequest.StartDate.Date);
            command.Parameters.AddWithValue("@EndDate", leaveRequest.EndDate.Date);
            command.Parameters.AddWithValue("@Reason", leaveRequest.Reason.Trim());

            SqlParameter returnValueParameter = new("@ReturnValue", SqlDbType.Int)
            {
                Direction = ParameterDirection.ReturnValue
            };
            command.Parameters.Add(returnValueParameter);

            await command.ExecuteNonQueryAsync();
            return returnValueParameter.Value is int rv ? rv : Convert.ToInt32(returnValueParameter.Value ?? 0);
        }
        catch (SqlException ex) when (ex.Number is 547 or 515)
        {
            return 0;
        }
    }

    public async Task<int> DeleteLeaveAsync(int leaveRequestId)
    {
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_CancelLeave", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@LeaveRequestId", leaveRequestId);

        SqlParameter returnValueParameter = new("@ReturnValue", SqlDbType.Int)
        {
            Direction = ParameterDirection.ReturnValue
        };
        command.Parameters.Add(returnValueParameter);

        await command.ExecuteNonQueryAsync();
        return returnValueParameter.Value is int rv ? rv : Convert.ToInt32(returnValueParameter.Value ?? 0);
    }

    public async Task<int> ApproveLeaveAsync(int leaveRequestId, int approvedBy, string remarks)
    {
        try
        {
            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            await using SqlCommand command = new("sp_ApproveLeave", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.AddWithValue("@LeaveRequestId", leaveRequestId);
            command.Parameters.AddWithValue("@ApprovedBy", approvedBy);
            command.Parameters.AddWithValue("@Remarks", string.IsNullOrWhiteSpace(remarks) ? DBNull.Value : remarks.Trim());

            SqlParameter returnValueParameter = new("@ReturnValue", SqlDbType.Int)
            {
                Direction = ParameterDirection.ReturnValue
            };
            command.Parameters.Add(returnValueParameter);

            await command.ExecuteNonQueryAsync();
            return returnValueParameter.Value is int rv ? rv : Convert.ToInt32(returnValueParameter.Value ?? 0);
        }
        catch (SqlException ex) when (ex.Number is 547 or 515)
        {
            return 0;
        }
    }

    public async Task<int> RejectLeaveAsync(int leaveRequestId, int approvedBy, string remarks)
    {
        try
        {
            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            await using SqlCommand command = new("sp_RejectLeave", connection) { CommandType = CommandType.StoredProcedure };
            command.Parameters.AddWithValue("@LeaveRequestId", leaveRequestId);
            command.Parameters.AddWithValue("@ApprovedBy", approvedBy);
            command.Parameters.AddWithValue("@Remarks", string.IsNullOrWhiteSpace(remarks) ? DBNull.Value : remarks.Trim());

            SqlParameter returnValueParameter = new("@ReturnValue", SqlDbType.Int)
            {
                Direction = ParameterDirection.ReturnValue
            };
            command.Parameters.Add(returnValueParameter);

            await command.ExecuteNonQueryAsync();
            return returnValueParameter.Value is int rv ? rv : Convert.ToInt32(returnValueParameter.Value ?? 0);
        }
        catch (SqlException ex) when (ex.Number is 547 or 515)
        {
            return 0;
        }
    }

    public async Task<IEnumerable<LeaveRequestDto>> GetLeavesByEmployeeAsync(int employeeId)
    {
        List<LeaveRequestDto> leaves = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_GetLeaveHistory", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@EmployeeId", employeeId);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
            leaves.Add(MapLeaveRequest(reader));

        return leaves;
    }

    public async Task<IEnumerable<LeaveRequestDto>> GetPendingLeavesAsync()
    {
        List<LeaveRequestDto> leaves = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_GetPendingLeaveRequests", connection) { CommandType = CommandType.StoredProcedure };
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
            leaves.Add(MapLeaveRequest(reader));

        return leaves;
    }

    public async Task<IEnumerable<LeaveRequestDto>> GetLeavesByDateRangeAsync(DateTime fromDate, DateTime toDate)
    {
        List<LeaveRequestDto> leaves = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_GetLeavesByDateRange", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@FromDate", fromDate.Date);
        command.Parameters.AddWithValue("@ToDate", toDate.Date);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
            leaves.Add(MapLeaveRequest(reader));

        return leaves;
    }

    private static LeaveRequestDto MapLeaveRequest(SqlDataReader reader)
    {
        return new LeaveRequestDto
        {
            LeaveRequestId = Convert.ToInt32(reader["LeaveRequestId"]),
            EmployeeId = Convert.ToInt32(reader["EmployeeId"]),
            LeaveTypeId = Convert.ToInt32(reader["LeaveTypeId"]),
            StartDate = Convert.ToDateTime(reader["StartDate"]),
            EndDate = Convert.ToDateTime(reader["EndDate"]),
            TotalDays = Convert.ToInt32(reader["TotalDays"]),
            Reason = reader["Reason"].ToString()!,
            Status = reader["Status"].ToString()!,
            ApprovedBy = HasColumn(reader, "ApprovedBy") && reader["ApprovedBy"] != DBNull.Value
                ? Convert.ToInt32(reader["ApprovedBy"])
                : null,
            ApprovedDate = HasColumn(reader, "ApprovedDate") && reader["ApprovedDate"] != DBNull.Value
                ? Convert.ToDateTime(reader["ApprovedDate"])
                : null,
            Remarks = HasColumn(reader, "Remarks") && reader["Remarks"] != DBNull.Value
                ? reader["Remarks"].ToString()
                : null,
            IsCancelled = HasColumn(reader, "IsCancelled") && reader["IsCancelled"] != DBNull.Value
                && Convert.ToBoolean(reader["IsCancelled"])
        };
    }

    private static bool HasColumn(SqlDataReader reader, string columnName)
    {
        for (int i = 0; i < reader.FieldCount; i++)
        {
            if (string.Equals(reader.GetName(i), columnName, StringComparison.OrdinalIgnoreCase))
                return true;
        }

        return false;
    }
}
