using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;
using System.Collections.Generic;
using System.Threading.Tasks;
using Xunit;

namespace EmployeeLeaveManagment.Tests
{
    public class AnalyticsRepositoryTests
    {
        private class FakeAnalyticsRepository : IAnalyticsRepository
        {
            public Task<IEnumerable<AnalyticsDto>> GetLeaveTrendAnalysisAsync(int? year = null)
            {
                var data = new[]
                {
                    new AnalyticsDto
                    {
                        Month = 1,
                        Year = year ?? 0,
                        TotalLeaves = 5,
                        TotalDays = 10
                    }
                };

                return Task.FromResult<IEnumerable<AnalyticsDto>>(data);
            }

            public Task<IEnumerable<AnalyticsDto>> GetDepartmentComparisonAsync(int? year = null)
            {
                var data = new[]
                {
                    new AnalyticsDto
                    {
                        DepartmentName = "HR",
                        TotalLeaves = 7,
                        TotalDays = 15
                    }
                };

                return Task.FromResult<IEnumerable<AnalyticsDto>>(data);
            }

            public Task<IEnumerable<AnalyticsDto>> GetFrequentLeavePatternAsync()
            {
                var data = new[]
                {
                    new AnalyticsDto
                    {
                        EmployeeName = "Alice",
                        TotalLeaves = 2
                    }
                };

                return Task.FromResult<IEnumerable<AnalyticsDto>>(data);
            }

            public Task<IEnumerable<AnalyticsDto>> GetForecastLeaveUtilizationAsync()
            {
                var data = new[]
                {
                    new AnalyticsDto
                    {
                        DepartmentName = "HR",
                        LeaveType = "Sick",
                        TotalLeaves = 3
                    }
                };

                return Task.FromResult<IEnumerable<AnalyticsDto>>(data);
            }
        }

        [Fact]
        public async Task GetLeaveTrendAnalysisAsync_ReturnsExpectedResult()
        {
            var repo = new FakeAnalyticsRepository();
            var service = new AnalyticsService(repo);
            var results = await service.GetLeaveTrendAnalysisAsync(2025);
            var item = Assert.Single(results);
            Assert.Equal(2025, item.Year);
            Assert.Equal(5, item.TotalLeaves);
            Assert.Equal(10, item.TotalDays);
        }
    }
}
