using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;
using Xunit;

namespace EmployeeLeaveManagment.Tests;

public class AnalyticsRepositoryTests
{
    private sealed class FakeAnalyticsRepository : IAnalyticsRepository
    {
        public Task<IEnumerable<LeaveTrendDto>> GetLeaveTrendAnalysisAsync(int? year = null)
            => Task.FromResult<IEnumerable<LeaveTrendDto>>(new[]
            {
                new LeaveTrendDto
                {
                    Month = 1,
                    Year = year ?? 0,
                    TotalLeaves = 5,
                    TotalDays = 10,
                    MonthOverMonthChangePercent = null
                }
            });

        public Task<IEnumerable<DepartmentComparisonDto>> GetDepartmentComparisonAsync(int? year = null)
            => Task.FromResult<IEnumerable<DepartmentComparisonDto>>(new[]
            {
                new DepartmentComparisonDto
                {
                    Year = year ?? 0,
                    DepartmentName = "HR",
                    TotalLeaves = 7,
                    TotalDays = 15,
                    AverageLeaveDays = 2.14M
                }
            });

        public Task<IEnumerable<FrequentLeavePatternDto>> GetFrequentLeavePatternAsync()
            => Task.FromResult<IEnumerable<FrequentLeavePatternDto>>(new[]
            {
                new FrequentLeavePatternDto
                {
                    EmployeeCode = "EMP001",
                    EmployeeName = "Alice",
                    DepartmentName = "HR",
                    TotalLeaves = 2,
                    TotalDays = 4,
                    AverageLeaveDays = 2M
                }
            });

        public Task<IEnumerable<ForecastLeaveUtilizationDto>> GetForecastLeaveUtilizationAsync()
            => Task.FromResult<IEnumerable<ForecastLeaveUtilizationDto>>(new[]
            {
                new ForecastLeaveUtilizationDto
                {
                    DepartmentName = "HR",
                    LeaveType = "Sick",
                    ForecastLeaveCount = 3,
                    ForecastAverageDays = 2.5M
                }
            });
    }

    [Fact]
    public async Task GetLeaveTrendAnalysisAsync_ReturnsExpectedResult()
    {
        var service = new AnalyticsService(new FakeAnalyticsRepository());
        var results = await service.GetLeaveTrendAnalysisAsync(2025);
        var item = Assert.Single(results);
        Assert.Equal(2025, item.Year);
        Assert.Equal(5, item.TotalLeaves);
        Assert.Equal(10, item.TotalDays);
    }

    [Fact]
    public async Task GetDepartmentComparisonAsync_ReturnsAverageLeaveDays()
    {
        var service = new AnalyticsService(new FakeAnalyticsRepository());
        var item = Assert.Single(await service.GetDepartmentComparisonAsync(2026));
        Assert.Equal("HR", item.DepartmentName);
        Assert.Equal(2.14M, item.AverageLeaveDays);
    }
}
