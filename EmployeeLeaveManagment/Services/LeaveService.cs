using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Helpers;

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
            if (leaveRequestId <= 0)
                return null;

            return await _leaveRepository.GetLeaveByIdAsync(leaveRequestId);
        }

        public async Task<int> ApplyLeaveAsync(LeaveRequestDto leaveRequest)
        {
            if (LeaveRequestValidator.ValidateApply(leaveRequest) != null)
                return 0;

            leaveRequest.Reason = leaveRequest.Reason.Trim();
            return await _leaveRepository.ApplyLeaveAsync(leaveRequest);
        }

        public async Task<int> UpdateLeaveAsync(LeaveRequestDto leaveRequest)
        {
            if (LeaveRequestValidator.ValidateUpdate(leaveRequest) != null)
                return 0;

            leaveRequest.Reason = leaveRequest.Reason.Trim();
            return await _leaveRepository.UpdateLeaveAsync(leaveRequest);
        }

        public async Task<int> DeleteLeaveAsync(int leaveRequestId)
        {
            if (leaveRequestId <= 0)
                return 0;

            return await _leaveRepository.DeleteLeaveAsync(leaveRequestId);
        }

        public async Task<int> ApproveLeaveAsync(int leaveRequestId, int approvedBy, string remarks)
        {
            if (LeaveRequestValidator.ValidateApproval(leaveRequestId, approvedBy) != null)
                return 0;

            return await _leaveRepository.ApproveLeaveAsync(leaveRequestId, approvedBy, remarks ?? string.Empty);
        }

        public async Task<int> RejectLeaveAsync(int leaveRequestId, int approvedBy, string remarks)
        {
            if (LeaveRequestValidator.ValidateApproval(leaveRequestId, approvedBy) != null)
                return 0;

            return await _leaveRepository.RejectLeaveAsync(leaveRequestId, approvedBy, remarks ?? string.Empty);
        }

        public async Task<IEnumerable<LeaveRequestDto>> GetLeavesByEmployeeAsync(int employeeId)
        {
            if (employeeId <= 0)
                return Enumerable.Empty<LeaveRequestDto>();

            return await _leaveRepository.GetLeavesByEmployeeAsync(employeeId);
        }

        public async Task<IEnumerable<LeaveRequestDto>> GetPendingLeavesAsync()
        {
            return await _leaveRepository.GetPendingLeavesAsync();
        }

        public async Task<IEnumerable<LeaveRequestDto>> GetLeavesByDateRangeAsync(DateTime fromDate, DateTime toDate)
        {
            if (fromDate == default || toDate == default || fromDate > toDate)
                return Enumerable.Empty<LeaveRequestDto>();

            return await _leaveRepository.GetLeavesByDateRangeAsync(fromDate, toDate);
        }
    }
}
