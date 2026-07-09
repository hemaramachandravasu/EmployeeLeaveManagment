using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Services
{
    public interface ILeaveService
    {
        Task<IEnumerable<LeaveRequestDto>> GetAllLeavesAsync();

        Task<LeaveRequestDto?> GetLeaveByIdAsync(int leaveRequestId);

        Task<int> ApplyLeaveAsync(LeaveRequestDto leaveRequest);

        Task<int> UpdateLeaveAsync(LeaveRequestDto leaveRequest);

        Task<int> DeleteLeaveAsync(int leaveRequestId);

        Task<int> ApproveLeaveAsync(int leaveRequestId, int approvedBy, string remarks);

        Task<int> RejectLeaveAsync(int leaveRequestId, int approvedBy, string remarks);

        Task<IEnumerable<LeaveRequestDto>> GetLeavesByEmployeeAsync(int employeeId);

        Task<IEnumerable<LeaveRequestDto>> GetPendingLeavesAsync();

        Task<IEnumerable<LeaveRequestDto>> GetLeavesByDateRangeAsync(DateTime fromDate, DateTime toDate);
    }
}
