namespace EmployeeLeaveManagment.Models
{
    public class EmployeeLeaveSummaryReport
    {
  
        public int EmployeeId { get; set; }
        public string EmployeeName { get; set; }
        public string Department { get; set; }
        public int TotalLeaves { get; set; }
        public int ApprovedLeaves { get; set; }
        public int PendingLeaves { get; set; }
        public int RejectedLeaves { get; set; }
    }
}