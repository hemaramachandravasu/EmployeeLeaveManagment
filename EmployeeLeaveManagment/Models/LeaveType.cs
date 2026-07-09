namespace EmployeeLeaveManagment.Models
{
    public class LeaveType
    {
        public int LeaveTypeId { get; set; }

        public string LeaveTypeName { get; set; } = string.Empty;

        public int TotalDays { get; set; }

        public string? Description { get; set; }

        public bool IsActive { get; set; }

        public DateTime CreatedDate { get; set; }

        public DateTime? ModifiedDate { get; set; }
    }
}
