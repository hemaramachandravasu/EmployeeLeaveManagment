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
    public void Validate_ReturnsNull_ForValidFilter()
    {
        var filter = new ReportFilterDto { Year = 2026, FromDate = new DateTime(2026, 1, 1), ToDate = new DateTime(2026, 12, 31) };
        Assert.Null(ReportFilterValidator.Validate(filter, requireBody: false));
    }
}
