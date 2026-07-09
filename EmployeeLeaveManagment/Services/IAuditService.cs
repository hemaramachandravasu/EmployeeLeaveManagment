using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Services
{
    public interface IAuditService
    {
        Task<IEnumerable<AuditLogDto>> GetAllAuditLogsAsync();

        Task<AuditLogDto?> GetAuditLogByIdAsync(int auditId);

        Task<IEnumerable<AuditLogDto>> GetAuditLogsByTableAsync(string tableName);

        Task<IEnumerable<AuditLogDto>> GetAuditLogsByUserAsync(string changedBy);

        Task<IEnumerable<AuditLogDto>> GetAuditLogsByDateRangeAsync(DateTime fromDate, DateTime toDate);
    }
}
