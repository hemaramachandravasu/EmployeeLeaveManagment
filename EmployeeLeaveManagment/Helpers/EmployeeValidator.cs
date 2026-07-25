using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Helpers;

public static class EmployeeValidator
{
    private static readonly HashSet<string> AllowedGenders = new(StringComparer.OrdinalIgnoreCase)
    {
        "Male", "Female", "Other"
    };

    public static string? ValidateCreate(EmployeeDto? employee)
    {
        if (employee == null)
            return "Employee request body is required.";

        if (string.IsNullOrWhiteSpace(employee.EmployeeCode))
            return "EmployeeCode is required.";

        if (string.IsNullOrWhiteSpace(employee.FirstName))
            return "FirstName is required.";

        if (string.IsNullOrWhiteSpace(employee.Gender) || !AllowedGenders.Contains(employee.Gender.Trim()))
            return "Gender must be one of: Male, Female, Other.";

        if (employee.DateOfBirth == default)
            return "DateOfBirth is required.";

        if (employee.DateOfBirth.Date >= DateTime.UtcNow.Date)
            return "DateOfBirth must be in the past.";

        if (string.IsNullOrWhiteSpace(employee.MobileNumber))
            return "MobileNumber is required.";

        if (string.IsNullOrWhiteSpace(employee.Email))
            return "Email is required.";

        if (employee.DepartmentId <= 0)
            return "DepartmentId must be a positive integer.";

        if (employee.ManagerId.HasValue && employee.ManagerId.Value <= 0)
            return "ManagerId must be a positive integer when provided.";

        if (employee.ManagerId.HasValue && employee.EmployeeId > 0 && employee.ManagerId.Value == employee.EmployeeId)
            return "ManagerId cannot be the same as EmployeeId.";

        if (employee.JoinDate == default)
            return "JoinDate is required.";

        if (employee.JoinDate.Date > DateTime.UtcNow.Date.AddDays(30))
            return "JoinDate cannot be more than 30 days in the future.";

        if (employee.Salary < 0)
            return "Salary cannot be negative.";

        return null;
    }

    public static string MapAddResult(int result) => result switch
    {
        -1 => "DepartmentId does not exist.",
        -2 => "EmployeeCode already exists.",
        -3 => "ManagerId does not exist or the manager is inactive.",
        _ => "Unable to add employee. Verify request body values."
    };

    public static string MapUpdateResult(int result) => result switch
    {
        -1 => "Employee not found.",
        -2 => "DepartmentId does not exist.",
        -3 => "EmployeeCode already exists for another employee.",
        -4 => "ManagerId does not exist or the manager is inactive.",
        -5 => "ManagerId cannot be the same as EmployeeId.",
        _ => "Unable to update employee. Verify EmployeeId and request body values."
    };

    public static string MapDeleteResult(int result) => result switch
    {
        -1 => "Employee not found.",
        -2 => "Employee is already inactive.",
        _ => "Unable to delete employee."
    };
}
