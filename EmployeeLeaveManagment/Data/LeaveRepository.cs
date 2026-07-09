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
            leaves.Add(MapLeaveRequest(reader, includeRemarks: true));
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
            ApprovedBy = reader["ApprovedBy"] == DBNull.Value ? null : Convert.ToInt32(reader["ApprovedBy"]),
            ApprovedDate = reader["ApprovedDate"] == DBNull.Value ? null : Convert.ToDateTime(reader["ApprovedDate"]),
            Remarks = reader["Remarks"]?.ToString(),
            IsCancelled = Convert.ToBoolean(reader["IsCancelled"])
        };
    }

    public async Task<int> ApplyLeaveAsync(LeaveRequestDto leaveRequest)
    {
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_ApplyLeave", connection) { CommandType = CommandType.StoredProcedure };

        command.Parameters.AddWithValue("@EmployeeId", leaveRequest.EmployeeId);
        command.Parameters.AddWithValue("@LeaveTypeId", leaveRequest.LeaveTypeId);
        command.Parameters.AddWithValue("@StartDate", leaveRequest.StartDate);
        command.Parameters.AddWithValue("@EndDate", leaveRequest.EndDate);
        command.Parameters.AddWithValue("@Reason", leaveRequest.Reason);

        SqlParameter outputIdParameter = new("@NewLeaveRequestId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        command.Parameters.Add(outputIdParameter);
        SqlParameter returnValueParameter = new("@ReturnValue", SqlDbType.Int) { Direction = ParameterDirection.ReturnValue };
        command.Parameters.Add(returnValueParameter);

        int rowsAffected = await command.ExecuteNonQueryAsync();

        if (outputIdParameter.Value != DBNull.Value && outputIdParameter.Value != null)
        {
            int outputId = Convert.ToInt32(outputIdParameter.Value);
            if (outputId > 0) return outputId;
        }

        if (returnValueParameter.Value != DBNull.Value && returnValueParameter.Value != null)
        {
            int returnValue = Convert.ToInt32(returnValueParameter.Value);
            if (returnValue > 0) return returnValue;
        }

        return rowsAffected > 0 ? rowsAffected : 0;
    }

    public async Task<int> UpdateLeaveAsync(LeaveRequestDto leaveRequest)
    {
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_UpdateLeave", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@LeaveRequestId", leaveRequest.LeaveRequestId);
        command.Parameters.AddWithValue("@LeaveTypeId", leaveRequest.LeaveTypeId);
        command.Parameters.AddWithValue("@StartDate", leaveRequest.StartDate);
        command.Parameters.AddWithValue("@EndDate", leaveRequest.EndDate);
        command.Parameters.AddWithValue("@Reason", leaveRequest.Reason);
        return await command.ExecuteNonQueryAsync();
    }

    public async Task<int> DeleteLeaveAsync(int leaveRequestId)
    {
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_CancelLeave", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@LeaveRequestId", leaveRequestId);
        return await command.ExecuteNonQueryAsync();
    }

    public async Task<int> ApproveLeaveAsync(int leaveRequestId, int approvedBy, string remarks)
    {
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_ApproveLeave", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@LeaveRequestId", leaveRequestId);
        command.Parameters.AddWithValue("@ApprovedBy", approvedBy);
        command.Parameters.AddWithValue("@Remarks", remarks);
        return await command.ExecuteNonQueryAsync();
    }

    public async Task<int> RejectLeaveAsync(int leaveRequestId, int approvedBy, string remarks)
    {
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_RejectLeave", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@LeaveRequestId", leaveRequestId);
        command.Parameters.AddWithValue("@ApprovedBy", approvedBy);
        command.Parameters.AddWithValue("@Remarks", remarks);
        return await command.ExecuteNonQueryAsync();
    }

    public async Task<IEnumerable<LeaveRequestDto>> GetLeavesByEmployeeAsync(int employeeId)
    {
        List<LeaveRequestDto> leaves = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_GetLeaveHistory", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@EmployeeId", employeeId);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
            leaves.Add(MapLeaveRequest(reader, includeRemarks: true));

        return leaves;
    }

    public async Task<IEnumerable<LeaveRequestDto>> GetPendingLeavesAsync()
    {
        List<LeaveRequestDto> leaves = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_GetPendingLeaveRequests", connection) { CommandType = CommandType.StoredProcedure };
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
            leaves.Add(MapLeaveRequest(reader, includeRemarks: false));

        return leaves;
    }

    public async Task<IEnumerable<LeaveRequestDto>> GetLeavesByDateRangeAsync(DateTime fromDate, DateTime toDate)
    {
        List<LeaveRequestDto> leaves = new();
        await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
        await using SqlCommand command = new("sp_GetLeavesByDateRange", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@FromDate", fromDate);
        command.Parameters.AddWithValue("@ToDate", toDate);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
            leaves.Add(MapLeaveRequest(reader, includeRemarks: false));

        return leaves;
    }

    private static LeaveRequestDto MapLeaveRequest(SqlDataReader reader, bool includeRemarks)
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
            Remarks = includeRemarks ? reader["Remarks"]?.ToString() : null
        };
    }
}
