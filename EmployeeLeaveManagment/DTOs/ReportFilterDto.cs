namespace EmployeeLeaveManagment.DTOs
{
    public class ReportFilterDto
    {
        public DateTime? FromDate { get; set; }

        public DateTime? ToDate { get; set; }

        public int? DepartmentId { get; set; }

        public int? EmployeeId { get; set; }

        public string? EmployeeName { get; set; }

        public int? Year { get; set; }

        public int? Month { get; set; }
    }
}