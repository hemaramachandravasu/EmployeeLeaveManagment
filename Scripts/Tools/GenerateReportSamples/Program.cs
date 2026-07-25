using ClosedXML.Excel;

var outDir = args.Length > 0
    ? args[0]
    : Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "Docs", "Samples", "Reporting"));

Directory.CreateDirectory(outDir);

WriteWorkbook(
    Path.Combine(outDir, "EmployeeLeaveSummary_Sample.xlsx"),
    "Employee Leave Summary",
    ["Employee Code", "Employee Name", "Department", "Leave Type", "Start Date", "End Date", "Total Days", "Status"],
    [
        ["EMP001", "Alice Johnson", "Engineering", "Annual Leave", "2026-01-10", "2026-01-12", 3, "Approved"],
        ["EMP002", "Bob Smith", "Engineering", "Sick Leave", "2026-02-05", "2026-02-06", 2, "Approved"],
        ["EMP003", "Carol Lee", "Human Resources", "Casual Leave", "2026-03-01", "2026-03-01", 1, "Pending"]
    ]);

WriteWorkbook(
    Path.Combine(outDir, "MonthlyLeaveUtilization_Sample.xlsx"),
    "Monthly Utilization",
    ["Employee Code", "Employee Name", "Department", "Leave Type", "Total Days", "Status"],
    [
        ["EMP001", "Alice Johnson", "Engineering", "Annual Leave", 3, "Approved"],
        ["EMP002", "Bob Smith", "Engineering", "Sick Leave", 2, "Approved"],
        ["EMP003", "Carol Lee", "Human Resources", "Casual Leave", 1, "Pending"]
    ]);

WriteWorkbook(
    Path.Combine(outDir, "DepartmentStatistics_Sample.xlsx"),
    "Department Statistics",
    ["Department", "Total Leave Days"],
    [
        ["Engineering", 5],
        ["Finance", 0],
        ["Human Resources", 1]
    ]);

WriteWorkbook(
    Path.Combine(outDir, "PendingLeaveRequests_Sample.xlsx"),
    "Pending Leave Requests",
    ["Employee Code", "Employee Name", "Department", "Leave Type", "Start Date", "End Date", "Total Days", "Status"],
    [
        ["EMP003", "Carol Lee", "Human Resources", "Casual Leave", "2026-03-01", "2026-03-01", 1, "Pending"]
    ]);

Console.WriteLine($"Sample Excel files written to: {outDir}");

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
