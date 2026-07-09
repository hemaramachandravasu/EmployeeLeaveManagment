using System.ComponentModel.DataAnnotations;

namespace EmployeeLeaveManagment.DTOs
{
    public class DepartmentDto
    {
        public int DepartmentId { get; set; }

        [Required]
        [StringLength(20)]
        public string DepartmentCode { get; set; } = string.Empty;

        [Required]
        [StringLength(100)]
        public string DepartmentName { get; set; } = string.Empty;

        [StringLength(250)]
        public string? Description { get; set; }

        public bool IsActive { get; set; }
    }
}