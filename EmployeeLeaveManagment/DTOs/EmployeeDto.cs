using System.ComponentModel.DataAnnotations;

namespace EmployeeLeaveManagment.DTOs
{
    public class EmployeeDto
    {
        public int EmployeeId { get; set; }

        [Required]
        [StringLength(20)]
        public string EmployeeCode { get; set; } = string.Empty;

        [Required]
        [StringLength(50)]
        public string FirstName { get; set; } = string.Empty;

        [StringLength(50)]
        public string? LastName { get; set; }

        [Required]
        public string Gender { get; set; } = string.Empty;

        [Required]
        public DateTime DateOfBirth { get; set; }

        [Required]
        [StringLength(15)]
        public string MobileNumber { get; set; } = string.Empty;

        [Required]
        [EmailAddress]
        public string Email { get; set; } = string.Empty;

        [Required]
        public int DepartmentId { get; set; }

        public int? ManagerId { get; set; }

        public DateTime JoinDate { get; set; }

        public decimal Salary { get; set; }

        public string? Address { get; set; }

        public bool IsActive { get; set; }
    }
}