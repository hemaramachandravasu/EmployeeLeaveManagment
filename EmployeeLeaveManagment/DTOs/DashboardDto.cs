namespace EmployeeLeaveManagment.DTOs
{
    public class DashboardDto
    {
        public int TotalEmployees { get; set; }

        public int TotalDepartments { get; set; }

        public int TotalLeaveRequests { get; set; }

        public int PendingLeaves { get; set; }

        public int ApprovedLeaves { get; set; }

        public int RejectedLeaves { get; set; }

        public int TotalLeaveTypes { get; set; }
    }
}