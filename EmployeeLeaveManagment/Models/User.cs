namespace EmployeeLeaveManagment.Models
{
    public class User
    {
        public int UserId { get; set; }

        public string UserName { get; set; } = string.Empty;

        public string PasswordHash { get; set; } = string.Empty;

        public string Email { get; set; } = string.Empty;

        public int RoleId { get; set; }

        public bool IsActive { get; set; }

        public DateTime CreatedDate { get; set; }

        public DateTime? ModifiedDate { get; set; }

        public string RoleName { get; set; } = string.Empty;

        public int? EmployeeId { get; set; }

        public int? DepartmentId { get; set; }
    }
}
