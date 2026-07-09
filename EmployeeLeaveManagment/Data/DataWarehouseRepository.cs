using ClosedXML.Excel;
using EmployeeLeaveManagment.DTOs;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Text;

namespace EmployeeLeaveManagment.Data;

public class DataWarehouseRepository : IDataWarehouseRepository
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public DataWarehouseRepository(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IEnumerable<ForecastDemandDto>> GetForecastLeaveDemandAsync(DateTime? asOfDate = null)
    {
        List<ForecastDemandDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateDataWarehouseConnectionAsync();
        await using SqlCommand command = new("sp_ForecastLeaveDemand_Department", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@AsOfDate", (object?)asOfDate?.Date ?? DBNull.Value);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new ForecastDemandDto
            {
                DepartmentName = reader["DepartmentName"].ToString()!,
                ForecastYear = Convert.ToInt32(reader["ForecastYear"]),
                ForecastMonth = Convert.ToInt32(reader["ForecastMonth"]),
                ForecastMonthName = reader["ForecastMonthName"].ToString()!,
                ForecastedLeaveCount = Convert.ToInt32(reader["ForecastedLeaveCount"]),
                ForecastedLeaveDays = Convert.ToInt32(reader["ForecastedLeaveDays"]),
                Methodology = reader["Methodology"].ToString()!
            });
        }

        return results;
    }

    public async Task<IEnumerable<BurnoutRiskDto>> GetEmployeeBurnoutRiskAsync(int lookbackDays = 180)
    {
        List<BurnoutRiskDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateDataWarehouseConnectionAsync();
        await using SqlCommand command = new("sp_EmployeeBurnoutRisk", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@LookbackDays", lookbackDays);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new BurnoutRiskDto
            {
                EmployeeId = Convert.ToInt32(reader["EmployeeId"]),
                EmployeeCode = reader["EmployeeCode"].ToString()!,
                EmployeeName = reader["EmployeeName"].ToString()!,
                DepartmentName = reader["DepartmentName"].ToString()!,
                TotalLeaves = Convert.ToInt32(reader["TotalLeaves"]),
                TotalDays = Convert.ToDecimal(reader["TotalDays"]),
                AvgDaysPerLeave = Convert.ToDecimal(reader["AvgDaysPerLeave"]),
                MaxConsecutiveDays = Convert.ToDecimal(reader["MaxConsecutiveDays"]),
                LeavesLast90Days = Convert.ToInt32(reader["LeavesLast90Days"]),
                BurnoutRiskLevel = reader["BurnoutRiskLevel"].ToString()!,
                RiskReason = reader["RiskReason"].ToString()!
            });
        }

        return results;
    }

    public async Task<IEnumerable<PeakPeriodDto>> GetPeakLeavePeriodsAsync(int lookbackYears = 3, int topN = 10)
    {
        List<PeakPeriodDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateDataWarehouseConnectionAsync();
        await using SqlCommand command = new("sp_PeakLeavePeriods", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@LookbackYears", lookbackYears);
        command.Parameters.AddWithValue("@TopN", topN);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new PeakPeriodDto
            {
                PeriodType = reader["PeriodType"].ToString()!,
                PeriodLabel = reader["PeriodLabel"].ToString()!,
                Year = reader["Year"] == DBNull.Value ? null : Convert.ToInt32(reader["Year"]),
                Month = reader["Month"] == DBNull.Value ? null : Convert.ToInt32(reader["Month"]),
                WeekOfYear = reader["WeekOfYear"] == DBNull.Value ? null : Convert.ToInt32(reader["WeekOfYear"]),
                TotalLeaves = Convert.ToInt32(reader["TotalLeaves"]),
                TotalDays = Convert.ToDecimal(reader["TotalDays"])
            });
        }

        return results;
    }

    public async Task<IEnumerable<MomTrendDto>> GetMonthOverMonthTrendAsync(int? year = null)
    {
        List<MomTrendDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateDataWarehouseConnectionAsync();
        await using SqlCommand command = new("sp_DW_MonthOverMonthTrend", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@Year", (object?)year ?? DBNull.Value);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new MomTrendDto
            {
                Year = Convert.ToInt32(reader["Year"]),
                Month = Convert.ToInt32(reader["Month"]),
                MonthName = reader["MonthName"].ToString()!,
                TotalLeaves = Convert.ToInt32(reader["TotalLeaves"]),
                TotalDays = Convert.ToDecimal(reader["TotalDays"]),
                ApprovedDays = Convert.ToDecimal(reader["ApprovedDays"]),
                RejectedDays = Convert.ToDecimal(reader["RejectedDays"]),
                PrevMonthLeaves = reader["PrevMonthLeaves"] == DBNull.Value ? null : Convert.ToInt32(reader["PrevMonthLeaves"]),
                MomLeaveChangePct = reader["MomLeaveChangePct"] == DBNull.Value ? null : Convert.ToDecimal(reader["MomLeaveChangePct"])
            });
        }

        return results;
    }

    public async Task<IEnumerable<DepartmentHeatmapDto>> GetDepartmentUtilizationHeatmapAsync(int? year = null)
    {
        List<DepartmentHeatmapDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateDataWarehouseConnectionAsync();
        await using SqlCommand command = new("sp_DW_DepartmentUtilizationHeatmap", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@Year", (object?)year ?? DBNull.Value);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new DepartmentHeatmapDto
            {
                DepartmentName = reader["DepartmentName"].ToString()!,
                Month = Convert.ToInt32(reader["Month"]),
                MonthName = reader["MonthName"].ToString()!,
                TotalLeaves = Convert.ToInt32(reader["TotalLeaves"]),
                TotalDays = Convert.ToDecimal(reader["TotalDays"]),
                UtilizationScore = reader["UtilizationScore"] == DBNull.Value ? null : Convert.ToDecimal(reader["UtilizationScore"])
            });
        }

        return results;
    }

    public async Task<IEnumerable<TopLeaveTypeDto>> GetTopLeaveTypesByVolumeAsync(int? year = null, int topN = 5)
    {
        List<TopLeaveTypeDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateDataWarehouseConnectionAsync();
        await using SqlCommand command = new("sp_DW_TopLeaveTypesByVolume", connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.AddWithValue("@Year", (object?)year ?? DBNull.Value);
        command.Parameters.AddWithValue("@TopN", topN);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new TopLeaveTypeDto
            {
                LeaveTypeName = reader["LeaveTypeName"].ToString()!,
                TotalRequests = Convert.ToInt32(reader["TotalRequests"]),
                TotalDays = Convert.ToDecimal(reader["TotalDays"]),
                ApprovedRequests = Convert.ToInt32(reader["ApprovedRequests"]),
                RejectedRequests = Convert.ToInt32(reader["RejectedRequests"])
            });
        }

        return results;
    }

    public async Task<IEnumerable<EtlRunLogDto>> GetEtlRunLogAsync(int topN = 20)
    {
        List<EtlRunLogDto> results = new();
        await using SqlConnection connection = await _connectionFactory.CreateDataWarehouseConnectionAsync();
        await using SqlCommand command = connection.CreateCommand();
        command.CommandText = """
            SELECT TOP (@TopN)
                ETLRunId, ProcessName, StartTime, EndTime, [Status],
                RowsInserted, RowsUpdated, ErrorMessage
            FROM dbo.ETL_RunLog
            ORDER BY ETLRunId DESC
            """;
        command.Parameters.AddWithValue("@TopN", topN);
        await using SqlDataReader reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            results.Add(new EtlRunLogDto
            {
                EtlRunId = Convert.ToInt32(reader["ETLRunId"]),
                ProcessName = reader["ProcessName"].ToString()!,
                StartTime = Convert.ToDateTime(reader["StartTime"]),
                EndTime = reader["EndTime"] == DBNull.Value ? null : Convert.ToDateTime(reader["EndTime"]),
                Status = reader["Status"].ToString()!,
                RowsInserted = reader["RowsInserted"] == DBNull.Value ? null : Convert.ToInt32(reader["RowsInserted"]),
                RowsUpdated = reader["RowsUpdated"] == DBNull.Value ? null : Convert.ToInt32(reader["RowsUpdated"]),
                ErrorMessage = reader["ErrorMessage"] == DBNull.Value ? null : reader["ErrorMessage"].ToString()
            });
        }

        return results;
    }

    public async Task<byte[]> ExportForecastDemandExcelAsync(DateTime? asOfDate = null)
    {
        var data = (await GetForecastLeaveDemandAsync(asOfDate)).ToList();
        using XLWorkbook workbook = new();

        var summary = workbook.Worksheets.Add("Summary");
        summary.Cell(1, 1).Value = "Department";
        summary.Cell(1, 2).Value = "Forecast Month";
        summary.Cell(1, 3).Value = "Forecasted Leave Count";
        summary.Cell(1, 4).Value = "Forecasted Leave Days";
        summary.Row(1).Style.Font.Bold = true;

        int row = 2;
        foreach (var item in data)
        {
            summary.Cell(row, 1).Value = item.DepartmentName;
            summary.Cell(row, 2).Value = $"{item.ForecastMonthName} {item.ForecastYear}";
            summary.Cell(row, 3).Value = item.ForecastedLeaveCount;
            summary.Cell(row, 4).Value = item.ForecastedLeaveDays;
            row++;
        }

        var detail = workbook.Worksheets.Add("Detail");
        detail.Cell(1, 1).Value = "Department";
        detail.Cell(1, 2).Value = "Year";
        detail.Cell(1, 3).Value = "Month";
        detail.Cell(1, 4).Value = "Month Name";
        detail.Cell(1, 5).Value = "Forecasted Count";
        detail.Cell(1, 6).Value = "Forecasted Days";
        detail.Cell(1, 7).Value = "Methodology";
        detail.Row(1).Style.Font.Bold = true;

        row = 2;
        foreach (var item in data)
        {
            detail.Cell(row, 1).Value = item.DepartmentName;
            detail.Cell(row, 2).Value = item.ForecastYear;
            detail.Cell(row, 3).Value = item.ForecastMonth;
            detail.Cell(row, 4).Value = item.ForecastMonthName;
            detail.Cell(row, 5).Value = item.ForecastedLeaveCount;
            detail.Cell(row, 6).Value = item.ForecastedLeaveDays;
            detail.Cell(row, 7).Value = item.Methodology;
            row++;
        }

        using MemoryStream stream = new();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }

    public async Task<byte[]> ExportBurnoutRiskExcelAsync(int lookbackDays = 180)
    {
        var data = (await GetEmployeeBurnoutRiskAsync(lookbackDays)).ToList();
        using XLWorkbook workbook = new();

        var summary = workbook.Worksheets.Add("Summary");
        summary.Cell(1, 1).Value = "Risk Level";
        summary.Cell(1, 2).Value = "Employee Count";
        summary.Row(1).Style.Font.Bold = true;

        var grouped = data.GroupBy(x => x.BurnoutRiskLevel)
            .Select(g => new { RiskLevel = g.Key, Count = g.Count() })
            .OrderByDescending(x => x.RiskLevel);

        int row = 2;
        foreach (var item in grouped)
        {
            summary.Cell(row, 1).Value = item.RiskLevel;
            summary.Cell(row, 2).Value = item.Count;
            row++;
        }

        var detail = workbook.Worksheets.Add("Detail");
        detail.Cell(1, 1).Value = "Employee Code";
        detail.Cell(1, 2).Value = "Employee Name";
        detail.Cell(1, 3).Value = "Department";
        detail.Cell(1, 4).Value = "Total Leaves";
        detail.Cell(1, 5).Value = "Total Days";
        detail.Cell(1, 6).Value = "Risk Level";
        detail.Cell(1, 7).Value = "Risk Reason";
        detail.Row(1).Style.Font.Bold = true;

        row = 2;
        foreach (var item in data)
        {
            detail.Cell(row, 1).Value = item.EmployeeCode;
            detail.Cell(row, 2).Value = item.EmployeeName;
            detail.Cell(row, 3).Value = item.DepartmentName;
            detail.Cell(row, 4).Value = item.TotalLeaves;
            detail.Cell(row, 5).Value = item.TotalDays;
            detail.Cell(row, 6).Value = item.BurnoutRiskLevel;
            detail.Cell(row, 7).Value = item.RiskReason;
            row++;
        }

        using MemoryStream stream = new();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }

    public async Task<byte[]> ExportPeakPeriodsExcelAsync(int lookbackYears = 3, int topN = 10)
    {
        var data = (await GetPeakLeavePeriodsAsync(lookbackYears, topN)).ToList();
        using XLWorkbook workbook = new();

        var summary = workbook.Worksheets.Add("Summary");
        summary.Cell(1, 1).Value = "Period Type";
        summary.Cell(1, 2).Value = "Period";
        summary.Cell(1, 3).Value = "Total Leaves";
        summary.Cell(1, 4).Value = "Total Days";
        summary.Row(1).Style.Font.Bold = true;

        int row = 2;
        foreach (var item in data)
        {
            summary.Cell(row, 1).Value = item.PeriodType;
            summary.Cell(row, 2).Value = item.PeriodLabel;
            summary.Cell(row, 3).Value = item.TotalLeaves;
            summary.Cell(row, 4).Value = item.TotalDays;
            row++;
        }

        var detail = workbook.Worksheets.Add("Detail");
        detail.Cell(1, 1).Value = "Period Type";
        detail.Cell(1, 2).Value = "Period Label";
        detail.Cell(1, 3).Value = "Year";
        detail.Cell(1, 4).Value = "Month";
        detail.Cell(1, 5).Value = "Week";
        detail.Cell(1, 6).Value = "Total Leaves";
        detail.Cell(1, 7).Value = "Total Days";
        detail.Row(1).Style.Font.Bold = true;

        row = 2;
        foreach (var item in data)
        {
            detail.Cell(row, 1).Value = item.PeriodType;
            detail.Cell(row, 2).Value = item.PeriodLabel;
            detail.Cell(row, 3).Value = item.Year;
            detail.Cell(row, 4).Value = item.Month;
            detail.Cell(row, 5).Value = item.WeekOfYear;
            detail.Cell(row, 6).Value = item.TotalLeaves;
            detail.Cell(row, 7).Value = item.TotalDays;
            row++;
        }

        using MemoryStream stream = new();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }

    public async Task<byte[]> ExportMomTrendExcelAsync(int? year = null)
    {
        var data = (await GetMonthOverMonthTrendAsync(year)).ToList();
        using XLWorkbook workbook = new();

        var summary = workbook.Worksheets.Add("Summary");
        summary.Cell(1, 1).Value = "Month";
        summary.Cell(1, 2).Value = "Total Leaves";
        summary.Cell(1, 3).Value = "MoM Change %";
        summary.Row(1).Style.Font.Bold = true;

        int row = 2;
        foreach (var item in data)
        {
            summary.Cell(row, 1).Value = item.MonthName;
            summary.Cell(row, 2).Value = item.TotalLeaves;
            summary.Cell(row, 3).Value = item.MomLeaveChangePct;
            row++;
        }

        var detail = workbook.Worksheets.Add("Detail");
        detail.Cell(1, 1).Value = "Year";
        detail.Cell(1, 2).Value = "Month";
        detail.Cell(1, 3).Value = "Month Name";
        detail.Cell(1, 4).Value = "Total Leaves";
        detail.Cell(1, 5).Value = "Total Days";
        detail.Cell(1, 6).Value = "Approved Days";
        detail.Cell(1, 7).Value = "Rejected Days";
        detail.Cell(1, 8).Value = "Prev Month Leaves";
        detail.Cell(1, 9).Value = "MoM Change %";
        detail.Row(1).Style.Font.Bold = true;

        row = 2;
        foreach (var item in data)
        {
            detail.Cell(row, 1).Value = item.Year;
            detail.Cell(row, 2).Value = item.Month;
            detail.Cell(row, 3).Value = item.MonthName;
            detail.Cell(row, 4).Value = item.TotalLeaves;
            detail.Cell(row, 5).Value = item.TotalDays;
            detail.Cell(row, 6).Value = item.ApprovedDays;
            detail.Cell(row, 7).Value = item.RejectedDays;
            detail.Cell(row, 8).Value = item.PrevMonthLeaves;
            detail.Cell(row, 9).Value = item.MomLeaveChangePct;
            row++;
        }

        using MemoryStream stream = new();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }

    public async Task<string> ExportForecastDemandCsvAsync(DateTime? asOfDate = null)
    {
        var data = await GetForecastLeaveDemandAsync(asOfDate);
        StringBuilder csv = new();
        csv.AppendLine("Department,ForecastYear,ForecastMonth,ForecastMonthName,ForecastedLeaveCount,ForecastedLeaveDays,Methodology");
        foreach (var item in data)
        {
            csv.AppendLine($"{item.DepartmentName},{item.ForecastYear},{item.ForecastMonth},{item.ForecastMonthName},{item.ForecastedLeaveCount},{item.ForecastedLeaveDays},{item.Methodology}");
        }
        return csv.ToString();
    }

    public async Task<string> ExportBurnoutRiskCsvAsync(int lookbackDays = 180)
    {
        var data = await GetEmployeeBurnoutRiskAsync(lookbackDays);
        StringBuilder csv = new();
        csv.AppendLine("EmployeeCode,EmployeeName,Department,TotalLeaves,TotalDays,AvgDaysPerLeave,MaxConsecutiveDays,LeavesLast90Days,BurnoutRiskLevel,RiskReason");
        foreach (var item in data)
        {
            csv.AppendLine($"{item.EmployeeCode},{item.EmployeeName},{item.DepartmentName},{item.TotalLeaves},{item.TotalDays},{item.AvgDaysPerLeave},{item.MaxConsecutiveDays},{item.LeavesLast90Days},{item.BurnoutRiskLevel},{item.RiskReason}");
        }
        return csv.ToString();
    }

    public async Task<string> ExportPeakPeriodsCsvAsync(int lookbackYears = 3, int topN = 10)
    {
        var data = await GetPeakLeavePeriodsAsync(lookbackYears, topN);
        StringBuilder csv = new();
        csv.AppendLine("PeriodType,PeriodLabel,Year,Month,WeekOfYear,TotalLeaves,TotalDays");
        foreach (var item in data)
        {
            csv.AppendLine($"{item.PeriodType},{item.PeriodLabel},{item.Year},{item.Month},{item.WeekOfYear},{item.TotalLeaves},{item.TotalDays}");
        }
        return csv.ToString();
    }

    public async Task<string> ExportMomTrendCsvAsync(int? year = null)
    {
        var data = await GetMonthOverMonthTrendAsync(year);
        StringBuilder csv = new();
        csv.AppendLine("Year,Month,MonthName,TotalLeaves,TotalDays,ApprovedDays,RejectedDays,PrevMonthLeaves,MomLeaveChangePct");
        foreach (var item in data)
        {
            csv.AppendLine($"{item.Year},{item.Month},{item.MonthName},{item.TotalLeaves},{item.TotalDays},{item.ApprovedDays},{item.RejectedDays},{item.PrevMonthLeaves},{item.MomLeaveChangePct}");
        }
        return csv.ToString();
    }
}
