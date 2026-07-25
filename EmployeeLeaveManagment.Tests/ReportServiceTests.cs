using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;
using Moq;
using Xunit;

namespace EmployeeLeaveManagment.Tests;

public class ReportServiceCachingTests
{
    private readonly Mock<IReportRepository> _repo = new();
    private readonly Mock<ICacheService> _cache = new();

    private ReportService CreateService() => new(_repo.Object, _cache.Object);

    [Fact]
    public async Task GetDepartmentLeaveStatisticsAsync_OnCacheMiss_CallsRepositoryAndCaches()
    {
        var filter = new ReportFilterDto { FromDate = new DateTime(2026, 1, 1), ToDate = new DateTime(2026, 12, 31) };
        var expected = new List<ReportDto>
        {
            new() { DepartmentName = "Engineering", TotalDays = 12 }
        };

        List<ReportDto>? cachedOut = null;
        _cache.Setup(c => c.TryGetValue(It.IsAny<string>(), out cachedOut)).Returns(false);
        _repo.Setup(r => r.GetDepartmentLeaveStatisticsAsync(filter)).ReturnsAsync(expected);

        var result = (await CreateService().GetDepartmentLeaveStatisticsAsync(filter)).ToList();

        Assert.Single(result);
        Assert.Equal("Engineering", result[0].DepartmentName);
        _repo.Verify(r => r.GetDepartmentLeaveStatisticsAsync(filter), Times.Once);
        _cache.Verify(
            c => c.Set(It.Is<string>(k => k.Contains("department-statistics")), It.IsAny<List<ReportDto>>(), It.IsAny<int>()),
            Times.Once);
    }

    [Fact]
    public async Task GetDepartmentLeaveStatisticsAsync_OnCacheHit_DoesNotCallRepository()
    {
        var filter = new ReportFilterDto();
        var cached = new List<ReportDto>
        {
            new() { DepartmentName = "HR", TotalDays = 5 }
        };

        _cache
            .Setup(c => c.TryGetValue(It.IsAny<string>(), out cached))
            .Returns(true);

        var result = (await CreateService().GetDepartmentLeaveStatisticsAsync(filter)).ToList();

        Assert.Single(result);
        Assert.Equal("HR", result[0].DepartmentName);
        _repo.Verify(r => r.GetDepartmentLeaveStatisticsAsync(It.IsAny<ReportFilterDto>()), Times.Never);
    }

    [Fact]
    public async Task GetEmployeeLeaveSummaryAsync_PassesFilterToRepository_OnCacheMiss()
    {
        var filter = new ReportFilterDto
        {
            EmployeeName = "Alice",
            DepartmentId = 2,
            FromDate = new DateTime(2026, 1, 1),
            ToDate = new DateTime(2026, 6, 30)
        };

        List<ReportDto>? cachedOut = null;
        _cache.Setup(c => c.TryGetValue(It.IsAny<string>(), out cachedOut)).Returns(false);
        _repo.Setup(r => r.GetEmployeeLeaveSummaryAsync(It.IsAny<ReportFilterDto>()))
            .ReturnsAsync(new List<ReportDto>
            {
                new() { EmployeeName = "Alice Johnson", TotalDays = 3 }
            });

        var result = await CreateService().GetEmployeeLeaveSummaryAsync(filter);

        Assert.Single(result);
        _repo.Verify(r => r.GetEmployeeLeaveSummaryAsync(
            It.Is<ReportFilterDto>(f =>
                f.EmployeeName == "Alice" &&
                f.DepartmentId == 2 &&
                f.FromDate == filter.FromDate &&
                f.ToDate == filter.ToDate)), Times.Once);
    }

    [Fact]
    public async Task GetPendingLeaveRequestsAsync_DoesNotUseCache()
    {
        _repo.Setup(r => r.GetPendingLeaveRequestsAsync(null))
            .ReturnsAsync(new List<ReportDto> { new() { Status = "Pending" } });

        var result = await CreateService().GetPendingLeaveRequestsAsync();

        Assert.Single(result);
        _cache.Verify(c => c.TryGetValue(It.IsAny<string>(), out It.Ref<List<ReportDto>?>.IsAny), Times.Never);
        _cache.Verify(c => c.Set(It.IsAny<string>(), It.IsAny<List<ReportDto>>(), It.IsAny<int>()), Times.Never);
        _repo.Verify(r => r.GetPendingLeaveRequestsAsync(null), Times.Once);
    }

    [Fact]
    public async Task GetDepartmentLeaveStatisticsAsync_PropagatesRepositoryException()
    {
        var filter = new ReportFilterDto();
        List<ReportDto>? cachedOut = null;
        _cache.Setup(c => c.TryGetValue(It.IsAny<string>(), out cachedOut)).Returns(false);
        _repo.Setup(r => r.GetDepartmentLeaveStatisticsAsync(filter))
            .ThrowsAsync(new InvalidOperationException("SQL failure"));

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            CreateService().GetDepartmentLeaveStatisticsAsync(filter));
    }

    [Fact]
    public async Task ExportEmployeeLeaveSummaryCsvAsync_DelegatesToRepository()
    {
        var filter = new ReportFilterDto { Year = 2026 };
        _repo.Setup(r => r.ExportEmployeeLeaveSummaryCsvAsync(filter))
            .ReturnsAsync("EmployeeCode,EmployeeName\nEMP001,Alice");

        var csv = await CreateService().ExportEmployeeLeaveSummaryCsvAsync(filter);

        Assert.Contains("EMP001", csv);
        _repo.Verify(r => r.ExportEmployeeLeaveSummaryCsvAsync(filter), Times.Once);
    }
}

public class ReportServiceLegacyTests
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

        public Task<IEnumerable<ReportDto>> GetPendingLeaveRequestsAsync(ReportFilterDto? filter = null) =>
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

    private sealed class NoOpCache : ICacheService
    {
        public T? Get<T>(string key) => default;
        public void Set<T>(string key, T value, int expirationMinutes) { }
        public void Remove(string key) { }
        public bool TryGetValue<T>(string key, out T value)
        {
            value = default!;
            return false;
        }
    }

    [Fact]
    public async Task GetPendingLeaveRequestsAsync_ReturnsRows()
    {
        var service = new ReportService(new FakeReportRepository(), new NoOpCache());
        var rows = await service.GetPendingLeaveRequestsAsync();
        var row = Assert.Single(rows);
        Assert.Equal("Pending", row.Status);
    }

    [Fact]
    public async Task ExportEmployeeLeaveSummaryCsvAsync_ReturnsCsvHeader()
    {
        var service = new ReportService(new FakeReportRepository(), new NoOpCache());
        var csv = await service.ExportEmployeeLeaveSummaryCsvAsync(new ReportFilterDto());
        Assert.Contains("EMP001", csv);
    }
}
