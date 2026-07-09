using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Data
{
     public interface ILeaveRepository
    {
        // CRUD
        Task<IEnumerable<LeaveRequestDto>> GetAllLeavesAsync();

        Task<LeaveRequestDto?> GetLeaveByIdAsync(int leaveRequestId);

        Task<int> ApplyLeaveAsync(LeaveRequestDto leaveRequest);

        Task<int> UpdateLeaveAsync(LeaveRequestDto leaveRequest);

        Task<int> DeleteLeaveAsync(int leaveRequestId);

        // Approval
        Task<int> ApproveLeaveAsync(int leaveRequestId, int approvedBy, string remarks);

        Task<int> RejectLeaveAsync(int leaveRequestId, int approvedBy, string remarks);

        // Reports
        Task<IEnumerable<LeaveRequestDto>> GetLeavesByEmployeeAsync(int employeeId);

        Task<IEnumerable<LeaveRequestDto>> GetPendingLeavesAsync();

        Task<IEnumerable<LeaveRequestDto>> GetLeavesByDateRangeAsync(DateTime fromDate, DateTime toDate);
    }
}