using ClosedXML.Excel;

var outDir = args.Length > 0
    ? args[0]
    : Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "Docs", "Samples", "Analytics"));

Directory.CreateDirectory(outDir);

WriteWorkbook(
    Path.Combine(outDir, "LeaveTrendAnalysis_Sample.xlsx"),
    "Leave Trend",
    ["Year", "Month", "TotalLeaves", "TotalDays"],
    [
        [2026, 1, 4, 12],
        [2026, 2, 3, 8],
        [2026, 3, 5, 15]
    ]);

WriteWorkbook(
    Path.Combine(outDir, "DepartmentComparison_Sample.xlsx"),
    "Department Comparison",
    ["DepartmentName", "TotalLeaves", "TotalDays"],
    [
        ["Engineering", 7, 20],
        ["Finance", 2, 4],
        ["Human Resources", 3, 5]
    ]);

WriteWorkbook(
    Path.Combine(outDir, "FrequentLeavePattern_Sample.xlsx"),
    "Frequent Leave Pattern",
    ["EmployeeCode", "EmployeeName", "DepartmentName", "TotalLeaves", "TotalDays", "AverageLeaveDays"],
    [
        ["EMP001", "Alice Johnson", "Engineering", 5, 14, 2.80],
        ["EMP002", "Bob Smith", "Engineering", 4, 10, 2.50],
        ["EMP003", "Carol Lee", "Human Resources", 3, 6, 2.00]
    ]);

WriteWorkbook(
    Path.Combine(outDir, "ForecastLeaveUtilization_Sample.xlsx"),
    "Forecast Utilization",
    ["DepartmentName", "LeaveType", "ForecastLeaveCount", "ForecastAverageDays"],
    [
        ["Engineering", "Annual Leave", 3, 3.50],
        ["Engineering", "Sick Leave", 2, 2.00],
        ["Human Resources", "Casual Leave", 2, 1.50]
    ]);

Console.WriteLine($"Analytics sample Excel files written to: {outDir}");

static void WriteWorkbook(string path, string sheetName, string[] headers, object[][] rows)
{
    using var workbook = new XLWorkbook();
    var ws = workbook.Worksheets.Add(sheetName);

    for (int c = 0; c < headers.Length; c++)
    {
        ws.Cell(1, c + 1).Value = headers[c];
        ws.Cell(1, c + 1).Style.Font.Bold = true;
    }

    for (int r = 0; r < rows.Length; r++)
    {
        for (int c = 0; c < rows[r].Length; c++)
            ws.Cell(r + 2, c + 1).Value = XLCellValue.FromObject(rows[r][c]);
    }

    ws.Columns().AdjustToContents();
    workbook.SaveAs(path);
}
