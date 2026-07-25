using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Helpers;
using Xunit;

namespace EmployeeLeaveManagment.Tests;

public class ReportFilterValidatorTests
{
    [Fact]
    public void Validate_ReturnsError_WhenFromDateAfterToDate()
    {
        var filter = new ReportFilterDto
        {
            FromDate = new DateTime(2026, 6, 1),
            ToDate = new DateTime(2026, 1, 1)
        };

        var error = ReportFilterValidator.Validate(filter, requireBody: false);
        Assert.Equal("FromDate must be on or before ToDate.", error);
    }

    [Fact]
    public void Validate_ReturnsError_WhenYearOutOfRange()
    {
        var filter = new ReportFilterDto { Year = 1999 };
        var error = ReportFilterValidator.Validate(filter, requireBody: false);
        Assert.Equal("Year must be between 2000 and 2100.", error);
    }

    [Fact]
    public void Validate_ReturnsError_WhenEmployeeNameTooLong()
    {
        var filter = new ReportFilterDto { EmployeeName = new string('A', 251) };
        var error = ReportFilterValidator.Validate(filter, requireBody: false);
        Assert.Equal("EmployeeName cannot exceed 250 characters.", error);
    }

    [Fact]
    public void Validate_ReturnsNull_ForValidEmployeeName()
    {
        var filter = new ReportFilterDto { EmployeeName = "Alice" };
        Assert.Null(ReportFilterValidator.Validate(filter, requireBody: false));
    }
}
