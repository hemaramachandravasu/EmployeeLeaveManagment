using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using Microsoft.Data.SqlClient;
using System.Data;

namespace EmployeeLeaveManagment.Data
{
    public class AuditRepository : IAuditRepository
    {
        private readonly ISqlConnectionFactory _connectionFactory;

        public AuditRepository(ISqlConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        public async Task<IEnumerable<AuditLogDto>> GetAllAuditLogsAsync()
        {
            List<AuditLogDto> logs = new();

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new("sp_GetAuditHistory", connection);

            command.CommandType = CommandType.StoredProcedure;

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                logs.Add(MapAuditLog(reader));
            }

            return logs;
        }

        public async Task<AuditLogDto?> GetAuditLogByIdAsync(int auditId)
        {
            AuditLogDto? log = null;

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new("sp_GetAuditLogById", connection);

            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.AddWithValue("@AuditId", auditId);

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                log = MapAuditLog(reader);
            }

            return log;
        }

        public async Task<IEnumerable<AuditLogDto>> GetAuditLogsByTableAsync(string tableName)
        {
            List<AuditLogDto> logs = new();

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new("sp_GetAuditLogsByTable", connection);

            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.AddWithValue("@TableName", tableName);

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                logs.Add(MapAuditLog(reader));
            }

            return logs;
        }
        public async Task<IEnumerable<AuditLogDto>> GetAuditLogsByUserAsync(string changedBy)
        {
            List<AuditLogDto> logs = new();

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new("sp_GetAuditLogsByUser", connection);

            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.AddWithValue("@ChangedBy", changedBy);

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                logs.Add(MapAuditLog(reader));
            }

            return logs;
        }

        public async Task<IEnumerable<AuditLogDto>> GetAuditLogsByDateRangeAsync(DateTime fromDate, DateTime toDate)
        {
            List<AuditLogDto> logs = new();

            await using SqlConnection connection = await _connectionFactory.CreateOpenConnectionAsync();
            using SqlCommand command = new("sp_GetAuditByDate", connection);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.AddWithValue("@FromDate", fromDate);
            command.Parameters.AddWithValue("@ToDate", toDate);

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                logs.Add(MapAuditLog(reader));
            }

            return logs;
        }

        private static AuditLogDto MapAuditLog(SqlDataReader reader)
        {
            return new AuditLogDto
            {
                AuditId = Convert.ToInt32(reader["AuditId"]),
                TableName = reader["TableName"].ToString()!,
                RecordId = Convert.ToInt32(reader["RecordId"]),
                ActionType = reader["ActionType"].ToString()!,
                OldValue = reader["OldValue"] == DBNull.Value ? null : reader["OldValue"].ToString(),
                NewValue = reader["NewValue"] == DBNull.Value ? null : reader["NewValue"].ToString(),
                ChangedBy = reader["ChangedBy"] == DBNull.Value ? null : reader["ChangedBy"].ToString(),
                ChangedOn = Convert.ToDateTime(reader["ChangedOn"])
            };
        }
    }
}