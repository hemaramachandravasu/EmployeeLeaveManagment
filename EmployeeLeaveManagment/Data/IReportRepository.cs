using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Models;
using System;
using System.Collections.Generic;

namespace EmployeeLeaveManagment.Data
{
    public interface IReportRepository
    {
        Task<IEnumerable<ReportDto>> GetEmployeeLeaveSummaryAsync(ReportFilterDto filter);

        Task<IEnumerable<ReportDto>> GetMonthlyLeaveUtilizationAsync(ReportFilterDto filter);

        Task<IEnumerable<ReportDto>> GetDepartmentLeaveStatisticsAsync(ReportFilterDto filter);

        Task<IEnumerable<ReportDto>> GetPendingLeaveRequestsAsync();

        Task<byte[]> ExportEmployeeLeaveSummaryExcelAsync(ReportFilterDto filter);

        Task<byte[]> ExportDepartmentStatisticsExcelAsync(ReportFilterDto filter);

        Task<string> ExportEmployeeLeaveSummaryCsvAsync(ReportFilterDto filter);

        Task<string> ExportDepartmentStatisticsCsvAsync(ReportFilterDto filter);
        IEnumerable<DepartmentLeaveStats> GetDepartmentLeaveStats(DateTime? fromDate, DateTime? toDate);

        IEnumerable<MonthlyLeaveUtilization> GetMonthlyLeaveUtilization(int year, int? departmentId, int? employeeId);
    }
}
