using System.Data;
using EmployeeLeaveManagment.Data;

namespace EmployeeLeaveManagment.Services;

public class ReportSchedulerService : BackgroundService
{
    private readonly ILogger<ReportSchedulerService> _logger;
    private readonly IConfiguration _configuration;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ExportService _exportService;
    private readonly TimeSpan _interval;

    public ReportSchedulerService(
        ILogger<ReportSchedulerService> logger,
        IConfiguration configuration,
        IServiceScopeFactory scopeFactory,
        ExportService exportService)
    {
        _logger = logger;
        _configuration = configuration;
        _scopeFactory = scopeFactory;
        _exportService = exportService;
        _interval = TimeSpan.FromHours(configuration.GetValue("Reporting:IntervalHours", 24));
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

    private async Task GenerateAndSaveReportsAsync(CancellationToken ct)
    {
        var folder = _configuration.GetValue<string>("Reporting:OutputFolder")
            ?? Path.Combine(AppContext.BaseDirectory, "Reports");
        Directory.CreateDirectory(folder);

        var now = DateTime.UtcNow;
        var fileBase = Path.Combine(folder, $"LeaveReport_{now:yyyyMMdd_HHmm}");

        using var scope = _scopeFactory.CreateScope();
        var reportRepo = scope.ServiceProvider.GetRequiredService<IReportRepository>();
        var analyticsService = scope.ServiceProvider.GetRequiredService<IAnalyticsService>();

        // Department stats — CSV + Excel
        var deptStats = reportRepo.GetDepartmentLeaveStats(null, null).ToList();
        var deptTable = ToDataTable(
            ["Department", "TotalEmployees", "TotalLeaves", "AvgLeaveDaysPerEmployee"],
            deptStats.Select(d => new object?[]
            {
                d.Department, d.TotalEmployees, d.TotalLeaves, d.AvgLeaveDaysPerEmployee
            }));
        await File.WriteAllBytesAsync(fileBase + "_DepartmentStats.csv", _exportService.ExportToCsv(deptTable), ct);
        await File.WriteAllBytesAsync(fileBase + "_DepartmentStats.xlsx", _exportService.ExportToExcel(deptTable), ct);

        // Monthly utilization — CSV + Excel
        var year = DateTime.UtcNow.Year;
        var monthly = reportRepo.GetMonthlyLeaveUtilization(year, null, null).ToList();
        var monthlyTable = ToDataTable(
            ["Year", "Month", "EmployeeId", "EmployeeName", "LeaveDays"],
            monthly.Select(m => new object?[]
            {
                m.Year, m.Month, m.EmployeeId, m.EmployeeName, m.LeaveDays
            }));
        await File.WriteAllBytesAsync(fileBase + "_MonthlyUtilization.csv", _exportService.ExportToCsv(monthlyTable), ct);
        await File.WriteAllBytesAsync(fileBase + "_MonthlyUtilization.xlsx", _exportService.ExportToExcel(monthlyTable), ct);

        // Analytics packs — CSV + Excel
        var trend = (await analyticsService.GetLeaveTrendAnalysisAsync(year)).ToList();
        var trendTable = ToDataTable(
            ["Year", "Month", "TotalLeaves", "TotalDays", "MonthOverMonthChangePercent"],
            trend.Select(t => new object?[]
            {
                t.Year, t.Month, t.TotalLeaves, t.TotalDays, t.MonthOverMonthChangePercent
            }));
        await File.WriteAllBytesAsync(fileBase + "_LeaveTrend.csv", _exportService.ExportToCsv(trendTable), ct);
        await File.WriteAllBytesAsync(fileBase + "_LeaveTrend.xlsx", _exportService.ExportToExcel(trendTable), ct);

        var deptCompare = (await analyticsService.GetDepartmentComparisonAsync(year)).ToList();
        var deptCompareTable = ToDataTable(
            ["Year", "DepartmentName", "TotalLeaves", "TotalDays", "AverageLeaveDays"],
            deptCompare.Select(d => new object?[]
            {
                d.Year, d.DepartmentName, d.TotalLeaves, d.TotalDays, d.AverageLeaveDays
            }));
        await File.WriteAllBytesAsync(fileBase + "_DepartmentComparison.csv", _exportService.ExportToCsv(deptCompareTable), ct);
        await File.WriteAllBytesAsync(fileBase + "_DepartmentComparison.xlsx", _exportService.ExportToExcel(deptCompareTable), ct);

        var frequent = (await analyticsService.GetFrequentLeavePatternAsync()).ToList();
        var frequentTable = ToDataTable(
            ["EmployeeCode", "EmployeeName", "DepartmentName", "TotalLeaves", "TotalDays", "AverageLeaveDays"],
            frequent.Select(f => new object?[]
            {
                f.EmployeeCode, f.EmployeeName, f.DepartmentName, f.TotalLeaves, f.TotalDays, f.AverageLeaveDays
            }));
        await File.WriteAllBytesAsync(fileBase + "_FrequentLeavePattern.csv", _exportService.ExportToCsv(frequentTable), ct);
        await File.WriteAllBytesAsync(fileBase + "_FrequentLeavePattern.xlsx", _exportService.ExportToExcel(frequentTable), ct);

        var forecast = (await analyticsService.GetForecastLeaveUtilizationAsync()).ToList();
        var forecastTable = ToDataTable(
            ["DepartmentName", "LeaveType", "ForecastLeaveCount", "ForecastAverageDays"],
            forecast.Select(f => new object?[]
            {
                f.DepartmentName, f.LeaveType, f.ForecastLeaveCount, f.ForecastAverageDays
            }));
        await File.WriteAllBytesAsync(fileBase + "_ForecastLeaveUtilization.csv", _exportService.ExportToCsv(forecastTable), ct);
        await File.WriteAllBytesAsync(fileBase + "_ForecastLeaveUtilization.xlsx", _exportService.ExportToExcel(forecastTable), ct);

        _logger.LogInformation("Reports generated (CSV + Excel) at {Folder}", folder);
    }

    private static DataTable ToDataTable(IReadOnlyList<string> columns, IEnumerable<object?[]> rows)
    {
        var table = new DataTable();
        foreach (var column in columns)
            table.Columns.Add(column);

        foreach (var row in rows)
            table.Rows.Add(row);

        return table;
    }
}
