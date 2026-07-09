using System;
using System.Data;
using System.Globalization;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.Models;
using System.Collections.Generic;

namespace EmployeeLeaveManagment.Services
{
    public class ReportSchedulerService : BackgroundService
    {
        private readonly ILogger<ReportSchedulerService> _logger;
        private readonly IConfiguration _configuration;
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly TimeSpan _interval;

        public ReportSchedulerService(ILogger<ReportSchedulerService> logger, IConfiguration configuration, IServiceScopeFactory scopeFactory)
        {
            _logger = logger;
            _configuration = configuration;
            _scopeFactory = scopeFactory;
            _interval = TimeSpan.FromHours(configuration.GetValue<int>("Reporting:IntervalHours", 24));
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("ReportSchedulerService started.");
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await GenerateAndSaveReportsAsync(stoppingToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error generating reports");
                }

                await Task.Delay(_interval, stoppingToken);
            }
        }

        private Task GenerateAndSaveReportsAsync(CancellationToken ct)
        {
            var folder = _configuration.GetValue<string>("Reporting:OutputFolder") ?? Path.Combine(AppContext.BaseDirectory, "Reports");
            Directory.CreateDirectory(folder);

            var now = DateTime.UtcNow;
            var fileBase = Path.Combine(folder, $"LeaveReport_{now:yyyyMMdd_HHmm}");

            using (var scope = _scopeFactory.CreateScope())
            {
                var repo = scope.ServiceProvider.GetRequiredService<IReportRepository>();

                // Department stats
                var deptStats = repo.GetDepartmentLeaveStats(null, null);
                var csvDept = new StringBuilder();
                csvDept.AppendLine("Department,TotalEmployees,TotalLeaves,AvgLeaveDaysPerEmployee");
                foreach (var d in deptStats)
                {
                    csvDept.AppendLine($"{EscapeCsv(d.Department)},{d.TotalEmployees},{d.TotalLeaves},{d.AvgLeaveDaysPerEmployee}");
                }
                File.WriteAllText(fileBase + "_DepartmentStats.csv", csvDept.ToString());

                // Monthly utilization for current year
                var month = DateTime.UtcNow.Year;
                var monthly = repo.GetMonthlyLeaveUtilization(month, null, null);
                var csvMonthly = new StringBuilder();
                csvMonthly.AppendLine("Year,Month,EmployeeId,EmployeeName,LeaveDays");
                foreach (var m in monthly)
                {
                    csvMonthly.AppendLine($"{m.Year},{m.Month},{m.EmployeeId},{EscapeCsv(m.EmployeeName)},{m.LeaveDays}");
                }
                File.WriteAllText(fileBase + "_MonthlyUtilization.csv", csvMonthly.ToString());
            }

            _logger.LogInformation("Reports generated at {Folder}", folder);
            return Task.CompletedTask;
        }

        private static string EscapeCsv(string? input)
        {
            if (string.IsNullOrEmpty(input)) return string.Empty;
            if (input.Contains(',') || input.Contains('"') || input.Contains('\r') || input.Contains('\n'))
            {
                return '"' + input.Replace("\"", "\"\"") + '"';
            }
            return input;
        }
    }
}
