using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;
using Xunit;

namespace EmployeeLeaveManagment.Tests;

public class ReportServiceTests
{
    private sealed class FakeReportRepository : IReportRepository
    {
        public Task<IEnumerable<ReportDto>> GetEmployeeLeaveSummaryAsync(ReportFilterDto filter) =>
            Task.FromResult<IEnumerable<ReportDto>>(new[]
            {
                new ReportDto { EmployeeCode = "EMP001", EmployeeName = "Alice Johnson", Status = "Approved", TotalDays = 3 }
            });

        public Task<IEnumerable<ReportDto>> GetMonthlyLeaveUtilizationAsync(ReportFilterDto filter) =>
            Task.FromResult<IEnumerable<ReportDto>>(Array.Empty<ReportDto>());

        public Task<IEnumerable<ReportDto>> GetDepartmentLeaveStatisticsAsync(ReportFilterDto filter) =>
            Task.FromResult<IEnumerable<ReportDto>>(new[]
            {
                new ReportDto { DepartmentName = "Engineering", TotalDays = 10 }
            });

        public Task<IEnumerable<ReportDto>> GetPendingLeaveRequestsAsync() =>
            Task.FromResult<IEnumerable<ReportDto>>(new[]
            {
                new ReportDto { EmployeeName = "Carol Lee", Status = "Pending" }
            });

        public Task<byte[]> ExportEmployeeLeaveSummaryExcelAsync(ReportFilterDto filter) =>
            Task.FromResult(Array.Empty<byte>());

        public Task<byte[]> ExportDepartmentStatisticsExcelAsync(ReportFilterDto filter) =>
            Task.FromResult(Array.Empty<byte>());

        public Task<string> ExportEmployeeLeaveSummaryCsvAsync(ReportFilterDto filter) =>
            Task.FromResult("EmployeeCode,EmployeeName\nEMP001,Alice");

        public Task<string> ExportDepartmentStatisticsCsvAsync(ReportFilterDto filter) =>
            Task.FromResult("Department,TotalLeaveDays\nEngineering,10");

        public IEnumerable<Models.DepartmentLeaveStats> GetDepartmentLeaveStats(DateTime? fromDate, DateTime? toDate) =>
            Array.Empty<Models.DepartmentLeaveStats>();

        public IEnumerable<Models.MonthlyLeaveUtilization> GetMonthlyLeaveUtilization(int year, int? departmentId, int? employeeId) =>
            Array.Empty<Models.MonthlyLeaveUtilization>();
    }

    [Fact]
    public async Task GetPendingLeaveRequestsAsync_ReturnsRows()
    {
        var service = new ReportService(new FakeReportRepository());
        var rows = await service.GetPendingLeaveRequestsAsync();
        var row = Assert.Single(rows);
        Assert.Equal("Pending", row.Status);
    }

    [Fact]
    public async Task ExportEmployeeLeaveSummaryCsvAsync_ReturnsCsvHeader()
    {
        var service = new ReportService(new FakeReportRepository());
        var csv = await service.ExportEmployeeLeaveSummaryCsvAsync(new ReportFilterDto());
        Assert.Contains("EMP001", csv);
    }
}
