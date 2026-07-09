using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Data
{
    public interface IAuditRepository
    {

        Task<IEnumerable<AuditLogDto>> GetAllAuditLogsAsync();

        Task<AuditLogDto?> GetAuditLogByIdAsync(int auditId);

        Task<IEnumerable<AuditLogDto>> GetAuditLogsByTableAsync(string tableName);

        Task<IEnumerable<AuditLogDto>> GetAuditLogsByUserAsync(string changedBy);

        Task<IEnumerable<AuditLogDto>> GetAuditLogsByDateRangeAsync(DateTime fromDate, DateTime toDate);
    }
}