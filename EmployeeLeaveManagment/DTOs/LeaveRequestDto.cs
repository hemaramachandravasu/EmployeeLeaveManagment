using System.ComponentModel.DataAnnotations;

namespace EmployeeLeaveManagment.DTOs
{
    public class LeaveRequestDto
    {
        public int LeaveRequestId { get; set; }

        [Required]
        [Range(1, int.MaxValue, ErrorMessage = "EmployeeId must be a positive integer.")]
        public int EmployeeId { get; set; }

        [Required]
        [Range(1, int.MaxValue, ErrorMessage = "LeaveTypeId must be a positive integer.")]
        public int LeaveTypeId { get; set; }

        [Required]
        public DateTime StartDate { get; set; }

        [Required]
        public DateTime EndDate { get; set; }

        public int TotalDays { get; set; }

        [Required]
        [MinLength(3, ErrorMessage = "Reason must be at least 3 characters.")]
        [StringLength(500, ErrorMessage = "Reason cannot exceed 500 characters.")]
        public string Reason { get; set; } = string.Empty;

        public string? Status { get; set; }

        public int? ApprovedBy { get; set; }

        public DateTime? ApprovedDate { get; set; }

        [StringLength(500, ErrorMessage = "Remarks cannot exceed 500 characters.")]
        public string? Remarks { get; set; }

        public bool IsCancelled { get; set; }
    }
}