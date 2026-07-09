using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Models;
using System;
using System.Collections.Generic;

namespace EmployeeLeaveManagment.Services
{
    public interface IReportService
    {
        Task<IEnumerable<ReportDto>> GetEmployeeLeaveSummaryAsync(ReportFilterDto filter);

        Task<IEnumerable<ReportDto>> GetMonthlyLeaveUtilizationAsync(ReportFilterDto filter);

        Task<IEnumerable<ReportDto>> GetDepartmentLeaveStatisticsAsync(ReportFilterDto filter);

        Task<IEnumerable<ReportDto>> GetPendingLeaveRequestsAsync();

        Task<byte[]> ExportEmployeeLeaveSummaryExcelAsync(ReportFilterDto filter);

        Task<byte[]> ExportDepartmentStatisticsExcelAsync(ReportFilterDto filter);

        Task<string> ExportEmployeeLeaveSummaryCsvAsync(ReportFilterDto filter);

        Task<string> ExportDepartmentStatisticsCsvAsync(ReportFilterDto filter);
    }
}
