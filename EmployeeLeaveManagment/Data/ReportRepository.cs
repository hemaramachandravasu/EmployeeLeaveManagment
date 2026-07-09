using ClosedXML.Excel;
using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Models;
using Microsoft.Data.SqlClient;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace EmployeeLeaveManagment.Data
{
   
    public class ReportRepository : IReportRepository
    {
        private readonly ISqlConnectionFactory _connectionFactory;

        public ReportRepository(ISqlConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        public async Task<IEnumerable<ReportDto>> GetEmployeeLeaveSummaryAsync(ReportFilterDto filter)
        {
            List<ReportDto> reports = new();

            await using SqlConnection connection = await _connectionFactory.CreateReportViewerConnectionAsync();

            using SqlCommand command = new("sp_EmployeeLeaveSummary", connection);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.AddWithValue("@FromDate", filter.FromDate ?? (object)DBNull.Value);
            command.Parameters.AddWithValue("@ToDate", filter.ToDate ?? (object)DBNull.Value);
            command.Parameters.AddWithValue("@DepartmentId", filter.DepartmentId ?? (object)DBNull.Value);
            command.Parameters.AddWithValue("@EmployeeId", filter.EmployeeId ?? (object)DBNull.Value);

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                reports.Add(new ReportDto
                {
                    EmployeeId = Convert.ToInt32(reader["EmployeeId"]),
                    EmployeeCode = reader["EmployeeCode"].ToString()!,
                    EmployeeName = reader["EmployeeName"].ToString()!,
                    DepartmentName = reader["DepartmentName"].ToString()!,
                    LeaveTypeName = reader["LeaveTypeName"].ToString()!,
                    StartDate = Convert.ToDateTime(reader["StartDate"]),
                    EndDate = Convert.ToDateTime(reader["EndDate"]),
                    TotalDays = Convert.ToInt32(reader["TotalDays"]),
                    Status = reader["Status"].ToString()!
                });
            }

            return reports;
        }

        public async Task<IEnumerable<ReportDto>> GetMonthlyLeaveUtilizationAsync(ReportFilterDto filter)
        {
            List<ReportDto> reports = new();

            await using SqlConnection connection = await _connectionFactory.CreateReportViewerConnectionAsync();

            using SqlCommand command = new("sp_MonthlyLeaveUtilization", connection);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.AddWithValue("@Year", filter.Year ?? (object)DBNull.Value);

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                reports.Add(new ReportDto
                {
                    EmployeeId = Convert.ToInt32(reader["EmployeeId"]),
                    EmployeeCode = reader["EmployeeCode"].ToString()!,
                    EmployeeName = reader["EmployeeName"].ToString()!,
                    DepartmentName = reader["DepartmentName"].ToString()!,
                    LeaveTypeName = reader["LeaveTypeName"].ToString()!,
                    TotalDays = Convert.ToInt32(reader["TotalDays"]),
                    Status = reader["Status"].ToString()!
                });
            }

            return reports;
        }

        public async Task<IEnumerable<ReportDto>> GetDepartmentLeaveStatisticsAsync(ReportFilterDto filter)
        {
            List<ReportDto> reports = new();

            await using SqlConnection connection = await _connectionFactory.CreateReportViewerConnectionAsync();

            using SqlCommand command = new("sp_DepartmentWiseLeaveStatistics", connection);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.AddWithValue("@FromDate", filter.FromDate ?? (object)DBNull.Value);
            command.Parameters.AddWithValue("@ToDate", filter.ToDate ?? (object)DBNull.Value);

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                reports.Add(new ReportDto
                {
                    DepartmentName = reader["DepartmentName"].ToString()!,
                    TotalDays = Convert.ToInt32(reader["TotalLeaveDays"])
                });
            }

            return reports;
        }
        public async Task<IEnumerable<ReportDto>> GetPendingLeaveRequestsAsync()
        {
            List<ReportDto> reports = new();

            await using SqlConnection connection = await _connectionFactory.CreateReportViewerConnectionAsync();
            using SqlCommand command = new("sp_PendingLeaveRequests", connection);

            command.CommandType = CommandType.StoredProcedure;

            using SqlDataReader reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                reports.Add(new ReportDto
                {
                    EmployeeId = reader["LeaveRequestId"] != DBNull.Value ? Convert.ToInt32(reader["LeaveRequestId"]) : 0,
                    EmployeeCode = reader["EmployeeCode"].ToString()!,
                    EmployeeName = reader["EmployeeName"].ToString()!,
                    DepartmentName = reader["DepartmentName"].ToString()!,
                    LeaveTypeName = reader["LeaveTypeName"].ToString()!,
                    StartDate = Convert.ToDateTime(reader["StartDate"]),
                    EndDate = Convert.ToDateTime(reader["EndDate"]),
                    TotalDays = Convert.ToInt32(reader["TotalDays"]),
                    Status = reader["Status"] != DBNull.Value ? reader["Status"].ToString()! : "Pending"
                });
            }

            return reports;
        }

        public async Task<byte[]> ExportEmployeeLeaveSummaryExcelAsync(ReportFilterDto filter)
        {
            var data = await GetEmployeeLeaveSummaryAsync(filter);

            using XLWorkbook workbook = new();
            var worksheet = workbook.Worksheets.Add("Employee Leave Summary");

            worksheet.Cell(1, 1).Value = "Employee Code";
            worksheet.Cell(1, 2).Value = "Employee Name";
            worksheet.Cell(1, 3).Value = "Department";
            worksheet.Cell(1, 4).Value = "Leave Type";
            worksheet.Cell(1, 5).Value = "Start Date";
            worksheet.Cell(1, 6).Value = "End Date";
            worksheet.Cell(1, 7).Value = "Total Days";
            worksheet.Cell(1, 8).Value = "Status";

            int row = 2;

            foreach (var item in data)
            {
                worksheet.Cell(row, 1).Value = item.EmployeeCode;
                worksheet.Cell(row, 2).Value = item.EmployeeName;
                worksheet.Cell(row, 3).Value = item.DepartmentName;
                worksheet.Cell(row, 4).Value = item.LeaveTypeName;
                worksheet.Cell(row, 5).Value = item.StartDate;
                worksheet.Cell(row, 6).Value = item.EndDate;
                worksheet.Cell(row, 7).Value = item.TotalDays;
                worksheet.Cell(row, 8).Value = item.Status;
                row++;
            }

            using MemoryStream stream = new();
            workbook.SaveAs(stream);

            return stream.ToArray();
        }

        public async Task<byte[]> ExportDepartmentStatisticsExcelAsync(ReportFilterDto filter)
        {
            var data = await GetDepartmentLeaveStatisticsAsync(filter);

            using XLWorkbook workbook = new();
            var worksheet = workbook.Worksheets.Add("Department Statistics");

            worksheet.Cell(1, 1).Value = "Department";
            worksheet.Cell(1, 2).Value = "Total Leave Days";

            int row = 2;

            foreach (var item in data)
            {
                worksheet.Cell(row, 1).Value = item.DepartmentName;
                worksheet.Cell(row, 2).Value = item.TotalDays;
                row++;
            }

            using MemoryStream stream = new();
            workbook.SaveAs(stream);

            return stream.ToArray();
        }

        public async Task<string> ExportEmployeeLeaveSummaryCsvAsync(ReportFilterDto filter)
        {
            var data = await GetEmployeeLeaveSummaryAsync(filter);

            StringBuilder csv = new();

            csv.AppendLine("EmployeeCode,EmployeeName,Department,LeaveType,StartDate,EndDate,TotalDays,Status");

            foreach (var item in data)
            {
                csv.AppendLine(
                    $"{item.EmployeeCode}," +
                    $"{item.EmployeeName}," +
                    $"{item.DepartmentName}," +
                    $"{item.LeaveTypeName}," +
                    $"{item.StartDate:yyyy-MM-dd}," +
                    $"{item.EndDate:yyyy-MM-dd}," +
                    $"{item.TotalDays}," +
                    $"{item.Status}");
            }

            return csv.ToString();
        }

        public async Task<string> ExportDepartmentStatisticsCsvAsync(ReportFilterDto filter)
        {
            var data = await GetDepartmentLeaveStatisticsAsync(filter);

            StringBuilder csv = new();

            csv.AppendLine("Department,TotalLeaveDays");

            foreach (var item in data)
            {
                csv.AppendLine($"{item.DepartmentName},{item.TotalDays}");
            }

            return csv.ToString();
        }
        public IEnumerable<DepartmentLeaveStats> GetDepartmentLeaveStats(DateTime? fromDate, DateTime? toDate)
        {
            var list = new List<DepartmentLeaveStats>();

            using SqlConnection conn = _connectionFactory.CreateReportViewerConnectionAsync().ConfigureAwait(false).GetAwaiter().GetResult();
            using SqlCommand cmd = new SqlCommand("sp_GetDepartmentLeaveStats", conn);

            cmd.CommandType = CommandType.StoredProcedure;

            cmd.Parameters.AddWithValue("@FromDate", (object?)fromDate ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@ToDate", (object?)toDate ?? DBNull.Value);

            

            using SqlDataReader dr = cmd.ExecuteReader();

            while (dr.Read())
            {
                list.Add(new DepartmentLeaveStats
                {
                    Department = dr["DepartmentName"].ToString(),
                    TotalEmployees = Convert.ToInt32(dr["TotalEmployees"]),
                    TotalLeaves = Convert.ToInt32(dr["TotalLeaves"]),
                    AvgLeaveDaysPerEmployee = Convert.ToDecimal(dr["AvgLeaveDaysPerEmployee"])
                });
            }

            return list;
        }

        public IEnumerable<MonthlyLeaveUtilization> GetMonthlyLeaveUtilization(int year, int? departmentId, int? employeeId)
        {
            var list = new List<MonthlyLeaveUtilization>();

            using SqlConnection conn = _connectionFactory.CreateReportViewerConnectionAsync().ConfigureAwait(false).GetAwaiter().GetResult();
            using SqlCommand cmd = new SqlCommand("sp_GetMonthlyLeaveUtilization", conn);

            cmd.CommandType = CommandType.StoredProcedure;

            cmd.Parameters.AddWithValue("@Year", year);

            

            using SqlDataReader dr = cmd.ExecuteReader();

            while (dr.Read())
            {
                list.Add(new MonthlyLeaveUtilization
                {
                    Year = Convert.ToInt32(dr["Year"]),
                    Month = Convert.ToInt32(dr["Month"]),
                    EmployeeId = Convert.ToInt32(dr["EmployeeId"]),
                    EmployeeName = dr["FullName"].ToString(),
                    LeaveDays = Convert.ToInt32(dr["LeaveDays"])
                });
            }

            return list;
        }
    }
}