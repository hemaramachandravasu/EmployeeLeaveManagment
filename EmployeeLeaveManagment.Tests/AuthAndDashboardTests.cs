using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Security;
using EmployeeLeaveManagment.Services;
using Xunit;

namespace EmployeeLeaveManagment.Tests;

public class AuthAndDashboardTests
{
    [Fact]
    public void PasswordHasher_Verifies_SeededAdminPassword()
    {
        const string stored = "100000.sVmZ2ZK8pGxLpN3YzQ8wFg==.NIyIfjMBgb7RfEaZ7gSu+7aB0pHL43cs/z1+iyXRoKY=";
        Assert.True(PasswordHasher.Verify("Admin@123", stored));
        Assert.False(PasswordHasher.Verify("wrong", stored));
    }

    [Fact]
    public async Task DashboardService_ReturnsDepartmentFeed_FromFakeRepository()
    {
        var repo = new FakeDashboardRepository();
        var service = new DashboardService(repo);

        var result = await service.GetDepartmentLeaveCountsAsync(2026);
        var item = Assert.Single(result);
        Assert.Equal("Engineering", item.DepartmentName);
        Assert.Equal(5, item.TotalLeaves);
    }

    private sealed class FakeDashboardRepository : IDashboardRepository
    {
        public Task<DashboardDto> GetDashboardDataAsync() =>
            Task.FromResult(new DashboardDto { TotalEmployees = 3, PendingLeaves = 1 });

        public Task<IEnumerable<DepartmentLeaveFeedDto>> GetDepartmentLeaveCountsAsync(int? year) =>
            Task.FromResult<IEnumerable<DepartmentLeaveFeedDto>>(new[]
            {
                new DepartmentLeaveFeedDto { DepartmentName = "Engineering", TotalLeaves = 5, TotalDays = 12 }
            });

        public Task<IEnumerable<MonthlyTrendFeedDto>> GetMonthlyUtilizationTrendAsync(int? year) =>
            Task.FromResult<IEnumerable<MonthlyTrendFeedDto>>(new[]
            {
                new MonthlyTrendFeedDto { Month = 1, Year = year ?? 2026, TotalLeaves = 2, TotalDays = 4 }
            });
    }
}
