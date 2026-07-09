using System;

namespace EmployeeLeaveManagment.Models
{

    public class Employee
    {
        public int EmployeeId { get; set; }

        public string EmployeeCode { get; set; } = string.Empty;

        public string FirstName { get; set; } = string.Empty;

        public string? LastName { get; set; }

        public string Gender { get; set; } = string.Empty;

        public DateTime DateOfBirth { get; set; }

        public string MobileNumber { get; set; } = string.Empty;

        public string Email { get; set; } = string.Empty;

        public int DepartmentId { get; set; }

        public int? ManagerId { get; set; }

        public DateTime JoinDate { get; set; }

        public decimal Salary { get; set; }

        public string? Address { get; set; }

        public bool IsActive { get; set; }

        public DateTime CreatedDate { get; set; }

        public DateTime? ModifiedDate { get; set; }
    }
}
