using System.ComponentModel.DataAnnotations;

namespace EmployeeLeaveManagment.DTOs
{

    public class LeaveTypeDto
    {
        public int LeaveTypeId { get; set; }

        [Required]
        [StringLength(50)]
        public string LeaveTypeName { get; set; } = string.Empty;

        [Required]
        public int TotalDays { get; set; }

        public string? Description { get; set; }

        public bool IsActive { get; set; }
    }
}