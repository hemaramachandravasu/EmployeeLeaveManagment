using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Helpers;

namespace EmployeeLeaveManagment.Tests;

public class Task1ValidationTests
{
    [Fact]
    public void ValidateApply_Rejects_InvalidDates()
    {
        var dto = new LeaveRequestDto
        {
            EmployeeId = 1,
            LeaveTypeId = 1,
            StartDate = new DateTime(2026, 7, 10),
            EndDate = new DateTime(2026, 7, 1),
            Reason = "Vacation"
        };

        string? error = LeaveRequestValidator.ValidateApply(dto);
        Assert.Equal("StartDate must be on or before EndDate.", error);
    }

    [Fact]
    public void ValidateApply_Rejects_MissingReason()
    {
        var dto = new LeaveRequestDto
        {
            EmployeeId = 1,
            LeaveTypeId = 1,
            StartDate = new DateTime(2026, 7, 1),
            EndDate = new DateTime(2026, 7, 2),
            Reason = "   "
        };

        string? error = LeaveRequestValidator.ValidateApply(dto);
        Assert.Equal("Reason is required.", error);
    }

    [Fact]
    public void MapApplyResult_Returns_SpecificMessages()
    {
        Assert.Contains("inactive", LeaveRequestValidator.MapApplyResult(-1));
        Assert.Contains("LeaveTypeId", LeaveRequestValidator.MapApplyResult(-2));
        Assert.Contains("Overlapping", LeaveRequestValidator.MapApplyResult(-4));
    }

    [Fact]
    public void ValidateCreate_Rejects_InvalidGender()
    {
        var dto = ValidEmployee();
        dto.Gender = "Unknown";

        string? error = EmployeeValidator.ValidateCreate(dto);
        Assert.Equal("Gender must be one of: Male, Female, Other.", error);
    }

    [Fact]
    public void ValidateCreate_Rejects_MissingDepartment()
    {
        var dto = ValidEmployee();
        dto.DepartmentId = 0;

        string? error = EmployeeValidator.ValidateCreate(dto);
        Assert.Equal("DepartmentId must be a positive integer.", error);
    }

    [Fact]
    public void MapAddResult_Returns_DuplicateCodeMessage()
    {
        Assert.Equal("EmployeeCode already exists.", EmployeeValidator.MapAddResult(-2));
    }

    [Fact]
    public void MapUpdateResult_Returns_NotFoundMessage()
    {
        Assert.Equal("Employee not found.", EmployeeValidator.MapUpdateResult(-1));
    }

    [Fact]
    public void MapDeleteResult_Returns_AlreadyInactiveMessage()
    {
        Assert.Equal("Employee is already inactive.", EmployeeValidator.MapDeleteResult(-2));
    }

    private static EmployeeDto ValidEmployee() => new()
    {
        EmployeeCode = "E100",
        FirstName = "Ada",
        Gender = "Female",
        DateOfBirth = new DateTime(1990, 1, 1),
        MobileNumber = "9876543210",
        Email = "ada@example.com",
        DepartmentId = 1,
        JoinDate = new DateTime(2024, 1, 1),
        Salary = 50000
    };
}
