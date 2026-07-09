using System;
using System.Collections.Generic;

using System.Data;
using System.Globalization;
using System.IO;
using System.Text;
using ClosedXML.Excel;

namespace EmployeeLeaveManagment.Services
{
    public class ExportService
    {
        public byte[] ExportToCsv(DataTable table)
        {
            var sb = new StringBuilder();
            for (int i = 0; i < table.Columns.Count; i++)
            {
                if (i > 0) sb.Append(',');
                sb.Append(EscapeCsv(table.Columns[i].ColumnName));
            }
            sb.AppendLine();

            foreach (DataRow row in table.Rows)
            {
                for (int i = 0; i < table.Columns.Count; i++)
                {
                    if (i > 0) sb.Append(',');
                    sb.Append(EscapeCsv(Convert.ToString(row[i], CultureInfo.InvariantCulture)));
                }
                sb.AppendLine();
            }

            return Encoding.UTF8.GetBytes(sb.ToString());
        }

        private string EscapeCsv(string? s)
        {
            if (s == null) return string.Empty;
            if (s.Contains(',') || s.Contains('"') || s.Contains('\n'))
                return '"' + s.Replace("\"", "\"\"") + '"';
            return s;
        }

        public byte[] ExportToExcel(DataTable table)
        {
            var workbook = new XLWorkbook();
            var worksheet = workbook.Worksheets.Add("Report");

            // Header Row
            for (int col = 0; col < table.Columns.Count; col++)
            {
                worksheet.Cell(1, col + 1).Value = table.Columns[col].ColumnName;
                worksheet.Cell(1, col + 1).Style.Font.Bold = true;
            }

            // Data Rows
            for (int row = 0; row < table.Rows.Count; row++)
            {
                for (int col = 0; col < table.Columns.Count; col++)
                {
                    object value = table.Rows[row][col];

                    worksheet.Cell(row + 2, col + 1).Value =
                        value == DBNull.Value
                        ? string.Empty
                        : value.ToString();
                }
            }

            // Adjust column widths
            worksheet.Columns().AdjustToContents();

            using var memoryStream = new MemoryStream();
            workbook.SaveAs(memoryStream);

            return memoryStream.ToArray();
        }

        public DataTable ToDataTable<T>(IEnumerable<T> data)
        {
            var table = new DataTable();
            bool columnsAdded = false;
            foreach (var item in data)
            {
                if (item == null) continue;
                var props = item.GetType().GetProperties();
                if (!columnsAdded)
                {
                    foreach (var p in props)
                        table.Columns.Add(p.Name, Nullable.GetUnderlyingType(p.PropertyType) ?? p.PropertyType);
                    columnsAdded = true;
                }
                var values = new object[props.Length];
                for (int i = 0; i < props.Length; i++)
                    values[i] = props[i].GetValue(item) ?? DBNull.Value;
                table.Rows.Add(values);
            }
            return table;
        }
    }
}
