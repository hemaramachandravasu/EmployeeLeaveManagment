using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;

namespace EmployeeLeaveManagment.Services
{
    public class AuditService : IAuditService
    {
        private readonly IAuditRepository _auditRepository;

        public AuditService(IAuditRepository auditRepository)
        {
            _auditRepository = auditRepository;
        }

        public async Task<IEnumerable<AuditLogDto>> GetAllAuditLogsAsync()
        {
            return await _auditRepository.GetAllAuditLogsAsync();
        }

        public async Task<AuditLogDto?> GetAuditLogByIdAsync(int auditId)
        {
            return await _auditRepository.GetAuditLogByIdAsync(auditId);
        }

        public async Task<IEnumerable<AuditLogDto>> GetAuditLogsByTableAsync(string tableName)
        {
            return await _auditRepository.GetAuditLogsByTableAsync(tableName);
        }

        public async Task<IEnumerable<AuditLogDto>> GetAuditLogsByUserAsync(string changedBy)
        {
            return await _auditRepository.GetAuditLogsByUserAsync(changedBy);
        }

        public async Task<IEnumerable<AuditLogDto>> GetAuditLogsByDateRangeAsync(DateTime fromDate, DateTime toDate)
        {
            return await _auditRepository.GetAuditLogsByDateRangeAsync(fromDate, toDate);
        }
    }
}