namespace EmployeeLeaveManagment.Models
{
    public class SchedulerLog
    {
        public int SchedulerLogId { get; set; }

        public string JobName { get; set; } = string.Empty;

        public DateTime ExecutionTime { get; set; }

        public string Status { get; set; } = string.Empty;

        public string Message { get; set; } = string.Empty;
    }
}