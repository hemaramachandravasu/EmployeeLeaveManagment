using System.ComponentModel.DataAnnotations;

namespace EmployeeLeaveManagment.DTOs
{
    public class DepartmentDto
    {
        public int DepartmentId { get; set; }

        [Required]
        [StringLength(50, MinimumLength = 1, ErrorMessage = "DepartmentCode is required (max 50 characters).")]
        public string DepartmentCode { get; set; } = string.Empty;

        [Required]
        [StringLength(200, MinimumLength = 1, ErrorMessage = "DepartmentName is required (max 200 characters).")]
        public string DepartmentName { get; set; } = string.Empty;

        [StringLength(250)]
        public string? Description { get; set; }

        public bool IsActive { get; set; }
    }
}