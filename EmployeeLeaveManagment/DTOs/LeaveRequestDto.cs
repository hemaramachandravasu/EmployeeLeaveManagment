using System.ComponentModel.DataAnnotations;

namespace EmployeeLeaveManagment.DTOs
{
    public class LeaveRequestDto
    {
        public int LeaveRequestId { get; set; }

        [Required]
        public int EmployeeId { get; set; }

        [Required]
        public int LeaveTypeId { get; set; }

        [Required]
        public DateTime StartDate { get; set; }

        [Required]
        public DateTime EndDate { get; set; }

        public int TotalDays { get; set; }

        [Required]
        [StringLength(500)]
        public string Reason { get; set; } = string.Empty;

        public string? Status { get; set; }

        public int? ApprovedBy { get; set; }

        public DateTime? ApprovedDate { get; set; }

        public string? Remarks { get; set; }

        public bool IsCancelled { get; set; }
    }
}