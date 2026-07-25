using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Helpers;

public static class LeaveRequestValidator
{
    public static string? ValidateApply(LeaveRequestDto? leaveRequest)
    {
        if (leaveRequest == null)
            return "Leave request body is required.";

        if (leaveRequest.EmployeeId <= 0)
            return "EmployeeId must be a positive integer.";

        if (leaveRequest.LeaveTypeId <= 0)
            return "LeaveTypeId must be a positive integer.";

        if (leaveRequest.StartDate == default)
            return "StartDate is required.";

        if (leaveRequest.EndDate == default)
            return "EndDate is required.";

        if (leaveRequest.StartDate.Date > leaveRequest.EndDate.Date)
            return "StartDate must be on or before EndDate.";

        if (string.IsNullOrWhiteSpace(leaveRequest.Reason))
            return "Reason is required.";

        if (leaveRequest.Reason.Trim().Length > 500)
            return "Reason cannot exceed 500 characters.";

        return null;
    }

    public static string? ValidateUpdate(LeaveRequestDto? leaveRequest)
    {
        string? applyError = ValidateApply(leaveRequest);
        if (applyError != null)
            return applyError;

        if (leaveRequest!.LeaveRequestId <= 0)
            return "LeaveRequestId must be a positive integer.";

        return null;
    }

    public static string? ValidateApproval(int leaveRequestId, int? approvedBy)
    {
        if (leaveRequestId <= 0)
            return "leaveRequestId must be a positive integer.";

        if (!approvedBy.HasValue || approvedBy.Value <= 0)
            return "approvedBy query parameter is required and must be a valid employee id.";

        return null;
    }

    public static string MapApplyResult(int result) => result switch
    {
        -1 => "EmployeeId does not exist or the employee is inactive.",
        -2 => "LeaveTypeId does not exist or the leave type is inactive.",
        -3 => "Invalid leave dates. StartDate must be on or before EndDate.",
        -4 => "Overlapping leave request already exists for this employee in the selected date range.",
        _ => "Unable to apply leave request. Verify input values and that employee/leave type exist."
    };

    public static string MapUpdateResult(int result) => result switch
    {
        -1 => "Leave request not found.",
        -2 => "Only pending, non-cancelled leave requests can be updated.",
        -3 => "LeaveTypeId does not exist or the leave type is inactive.",
        -4 => "Invalid leave dates. StartDate must be on or before EndDate.",
        _ => "Unable to update leave request. Verify LeaveRequestId and input values."
    };

    public static string MapApprovalResult(int result, string action) => result switch
    {
        -1 => "Leave request not found.",
        -2 => $"Only pending, non-cancelled leave requests can be {action}.",
        -3 => "approvedBy employee id does not exist or the employee is inactive.",
        _ => $"Unable to {action} leave request. Verify leave request id and approvedBy employee id."
    };
}
