namespace EmployeeLeaveManagment.DTOs
{

    public class AuditLogDto
    {
        public int AuditId { get; set; }

        public string TableName { get; set; } = string.Empty;

        public int RecordId { get; set; }

        public string ActionType { get; set; } = string.Empty;

        public string? OldValue { get; set; }

        public string? NewValue { get; set; }

        public string? ChangedBy { get; set; }

        public DateTime ChangedOn { get; set; }
    }
}