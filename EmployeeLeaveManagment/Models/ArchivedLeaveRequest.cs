namespace EmployeeLeaveManagment.Models
{

    public class ArchivedLeaveRequest
    {
        public int ArchiveId { get; set; }

        public int LeaveRequestId { get; set; }

        public int EmployeeId { get; set; }

        public int LeaveTypeId { get; set; }

        public DateTime StartDate { get; set; }

        public DateTime EndDate { get; set; }

        public int TotalDays { get; set; }

        public string Reason { get; set; } = string.Empty;

        public string Status { get; set; } = string.Empty;

        public DateTime ArchivedDate { get; set; }
    }
}