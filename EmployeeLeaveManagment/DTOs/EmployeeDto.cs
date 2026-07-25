using System.ComponentModel.DataAnnotations;

namespace EmployeeLeaveManagment.DTOs
{
    public class EmployeeDto
    {
        public int EmployeeId { get; set; }

        [Required]
        [StringLength(50, MinimumLength = 1, ErrorMessage = "EmployeeCode is required (max 50 characters).")]
        public string EmployeeCode { get; set; } = string.Empty;

        [Required]
        [StringLength(100, MinimumLength = 1, ErrorMessage = "FirstName is required (max 100 characters).")]
        public string FirstName { get; set; } = string.Empty;

        [StringLength(100)]
        public string? LastName { get; set; }

        [Required]
        [RegularExpression("(?i)^(Male|Female|Other)$", ErrorMessage = "Gender must be Male, Female, or Other.")]
        public string Gender { get; set; } = string.Empty;

        [Required]
        public DateTime DateOfBirth { get; set; }

        [Required]
        [StringLength(20, MinimumLength = 7, ErrorMessage = "MobileNumber must be 7-20 characters.")]
        public string MobileNumber { get; set; } = string.Empty;

        [Required]
        [EmailAddress]
        [StringLength(320)]
        public string Email { get; set; } = string.Empty;

        [Required]
        [Range(1, int.MaxValue, ErrorMessage = "DepartmentId must be a positive integer.")]
        public int DepartmentId { get; set; }

        [Range(1, int.MaxValue, ErrorMessage = "ManagerId must be a positive integer when provided.")]
        public int? ManagerId { get; set; }

        [Required]
        public DateTime JoinDate { get; set; }

        [Range(0, double.MaxValue, ErrorMessage = "Salary cannot be negative.")]
        public decimal Salary { get; set; }

        [StringLength(500)]
        public string? Address { get; set; }

        public bool IsActive { get; set; }
    }
}