using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.DTOs
{
    public class AnalyticsDto
    {
        public string? Category { get; set; }

        public string? DepartmentName { get; set; }

        public string? EmployeeCode { get; set; }

        public string? EmployeeName { get; set; }

        public string? LeaveType { get; set; }

        public int TotalLeaves { get; set; }

        public int TotalDays { get; set; }

        public decimal AverageLeaveDays { get; set; }

        public int Month { get; set; }

        public int Year { get; set; }
    }
}