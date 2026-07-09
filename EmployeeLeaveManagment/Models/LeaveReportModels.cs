using System;
using System.Collections.Generic;

namespace EmployeeLeaveManagment.Models
{
    public record EmployeeLeaveSummary
    (
        int EmployeeId,
        string EmployeeName,
        string Department,
        int TotalLeavesTaken,
        decimal TotalLeaveDays
    );

    public class MonthlyLeaveUtilization
    {
        public int Year { get; set; }
        public int Month { get; set; }
        public int EmployeeId { get; set; }
        public string EmployeeName { get; set; }
        public decimal LeaveDays { get; set; }

        // IMPORTANT FIX
        public MonthlyLeaveUtilization() { }

        public MonthlyLeaveUtilization(int year, int month, int employeeId, string employeeName, decimal leaveDays)
        {
            Year = year;
            Month = month;
            EmployeeId = employeeId;
            EmployeeName = employeeName;
            LeaveDays = leaveDays;
        }
    }

    public class DepartmentLeaveStats
    {
        public string Department { get; set; }
        public int TotalEmployees { get; set; }
        public int TotalLeaves { get; set; }
        public decimal AvgLeaveDaysPerEmployee { get; set; }

        // IMPORTANT: Add this
        public DepartmentLeaveStats() { }

        public DepartmentLeaveStats(string department, int totalEmployees, int totalLeaves, decimal avgLeaveDaysPerEmployee)
        {
            Department = department;
            TotalEmployees = totalEmployees;
            TotalLeaves = totalLeaves;
            AvgLeaveDaysPerEmployee = avgLeaveDaysPerEmployee;
        }
    }

    public record PendingLeaveRequest
    (
        int RequestId,
        int EmployeeId,
        string EmployeeName,
        string Department,
        DateTime FromDate,
        DateTime ToDate,
        string LeaveType,
        string Status
    );
}
