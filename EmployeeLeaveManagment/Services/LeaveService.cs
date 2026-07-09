using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;

namespace EmployeeLeaveManagment.Services
{
    public class LeaveService : ILeaveService
    {
        private readonly ILeaveRepository _leaveRepository;

        public LeaveService(ILeaveRepository leaveRepository)
        {
            _leaveRepository = leaveRepository;
        }

        public async Task<IEnumerable<LeaveRequestDto>> GetAllLeavesAsync()
        {
            return await _leaveRepository.GetAllLeavesAsync();
        }

        public async Task<LeaveRequestDto?> GetLeaveByIdAsync(int leaveRequestId)
        {
            return await _leaveRepository.GetLeaveByIdAsync(leaveRequestId);
        }

        public async Task<int> ApplyLeaveAsync(LeaveRequestDto leaveRequest)
        {
            if (leaveRequest == null)
                throw new ArgumentNullException(nameof(leaveRequest));

            if (leaveRequest.EmployeeId <= 0 || leaveRequest.LeaveTypeId <= 0)
                return 0;

            if (leaveRequest.StartDate == default || leaveRequest.EndDate == default || leaveRequest.StartDate > leaveRequest.EndDate)
                return 0;

            return await _leaveRepository.ApplyLeaveAsync(leaveRequest);
        }

        public async Task<int> UpdateLeaveAsync(LeaveRequestDto leaveRequest)
        {
            return await _leaveRepository.UpdateLeaveAsync(leaveRequest);
        }

        public async Task<int> DeleteLeaveAsync(int leaveRequestId)
        {
            return await _leaveRepository.DeleteLeaveAsync(leaveRequestId);
        }

        public async Task<int> ApproveLeaveAsync(int leaveRequestId, int approvedBy, string remarks)
        {
            return await _leaveRepository.ApproveLeaveAsync(leaveRequestId, approvedBy, remarks);
        }

        public async Task<int> RejectLeaveAsync(int leaveRequestId, int approvedBy, string remarks)
        {
            return await _leaveRepository.RejectLeaveAsync(leaveRequestId, approvedBy, remarks);
        }

        public async Task<IEnumerable<LeaveRequestDto>> GetLeavesByEmployeeAsync(int employeeId)
        {
            return await _leaveRepository.GetLeavesByEmployeeAsync(employeeId);
        }

        public async Task<IEnumerable<LeaveRequestDto>> GetPendingLeavesAsync()
        {
            return await _leaveRepository.GetPendingLeavesAsync();
        }

        public async Task<IEnumerable<LeaveRequestDto>> GetLeavesByDateRangeAsync(DateTime fromDate, DateTime toDate)
        {
            return await _leaveRepository.GetLeavesByDateRangeAsync(fromDate, toDate);
        }
    }
}