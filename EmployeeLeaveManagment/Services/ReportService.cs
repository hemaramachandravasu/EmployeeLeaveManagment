using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Models;
using EmployeeLeaveManagment.Services;
using System;
using System.Collections.Generic;

namespace EmployeeLeaveManagment.Services
{
    
    public class ReportService : IReportService
    {
        private readonly IReportRepository _reportRepository;

        public ReportService(IReportRepository reportRepository)
        {
            _reportRepository = reportRepository;
        }

        public async Task<IEnumerable<ReportDto>> GetEmployeeLeaveSummaryAsync(ReportFilterDto filter)
        {
            return await _reportRepository.GetEmployeeLeaveSummaryAsync(filter);
        }

        public async Task<IEnumerable<ReportDto>> GetMonthlyLeaveUtilizationAsync(ReportFilterDto filter)
        {
            return await _reportRepository.GetMonthlyLeaveUtilizationAsync(filter);
        }

        public async Task<IEnumerable<ReportDto>> GetDepartmentLeaveStatisticsAsync(ReportFilterDto filter)
        {
            return await _reportRepository.GetDepartmentLeaveStatisticsAsync(filter);
        }

        public async Task<IEnumerable<ReportDto>> GetPendingLeaveRequestsAsync()
        {
            return await _reportRepository.GetPendingLeaveRequestsAsync();
        }

        public async Task<byte[]> ExportEmployeeLeaveSummaryExcelAsync(ReportFilterDto filter)
        {
            return await _reportRepository.ExportEmployeeLeaveSummaryExcelAsync(filter);
        }

        public async Task<byte[]> ExportDepartmentStatisticsExcelAsync(ReportFilterDto filter)
        {
            return await _reportRepository.ExportDepartmentStatisticsExcelAsync(filter);
        }

        public async Task<string> ExportEmployeeLeaveSummaryCsvAsync(ReportFilterDto filter)
        {
            return await _reportRepository.ExportEmployeeLeaveSummaryCsvAsync(filter);
        }

        public async Task<string> ExportDepartmentStatisticsCsvAsync(ReportFilterDto filter)
        {
            return await _reportRepository.ExportDepartmentStatisticsCsvAsync(filter);
        }
    }
}