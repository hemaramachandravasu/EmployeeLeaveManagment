namespace EmployeeLeaveManagment.Models
{
    public class ReportHistory
    {
        public int ReportHistoryId { get; set; }

        public string ReportName { get; set; } = string.Empty;

        public string GeneratedBy { get; set; } = string.Empty;

        public DateTime GeneratedOn { get; set; }

        public string FileName { get; set; } = string.Empty;

        public string FileType { get; set; } = string.Empty;

        public int TotalRecords { get; set; }
    }
}