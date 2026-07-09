# Reporting, Audit Trail, and Archival Design

## Audit Trail Design
- Central table: dbo.AuditLogs captures TableName, KeyValue, Operation (I/U/D), OldValues (JSON), NewValues (JSON), ChangedBy, ChangedAt, TransactionId.
- Triggers added for dbo.Leaves and dbo.Employees to insert JSON snapshots into AuditLogs.
- Application should set SESSION_CONTEXT('CurrentUser') prior to executing DML so ChangedBy reflects real user id instead of service account.
- For very high write-throughput, consider an asynchronous pipeline (Service Broker, EventStream) to write audits off the critical path.

## Analytics Queries
- Stored procedures implemented under Scripts/Analytics:
  - sp_GetLeaveTrend: returns month-over-month totals and percent change.
  - sp_GetDepartmentComparison: aggregates per-department stats and averages.
  - sp_GetFrequentLeavePatterns: top N employees by leave count and days.
  - sp_GetForecastedLeaveUtilization: simple forecast based on last 12 months average.
- Keep heavy aggregations on the DB side for performance and network efficiency.

## Scheduling / Automation
- A .NET BackgroundService (ReportSchedulerService) was added to generate CSV reports periodically using IReportRepository.
- The service writes CSV to Reporting:OutputFolder (configurable in appsettings.json) on an interval defined by Reporting:IntervalHours.
- Alternative: Use SQL Server Agent jobs to run stored procedures and export results using sqlcmd or bcp.

## Archival Strategy
- Retention policy: move "closed" leaves older than 3 years to dbo.LeavesArchive on a monthly job.
- Implementation options:
  - Simple move via INSERT..DELETE in a transaction (suitable for moderate volumes).
  - Partitioning on FromDate + partition switch to archive table for large datasets (near-instant move).
- Ensure referential integrity: either archive related audit records or keep them in place and index/partition audit table.

## Indexing & Performance
- AuditLogs: index on (TableName, ChangedAt) and KeyValue; create filtered index for recent data.
- Leaves: index on FromDate, EmployeeId; consider computed MonthStart persisted column for month queries.
- Use Query Store and EXPLAIN plans to identify missing indexes and tune queries.

## Operational Notes
- Grant the application DB user INSERT permissions on dbo.AuditLogs and EXECUTE on analytics SPs.
- Deploy triggers and audit table to a non-production environment first and validate.

## Assumptions and Limitations
- Current reporting export writes CSV only to avoid adding external NuGet packages. If Excel (.xlsx) output is required, add a dependency such as ClosedXML and update ReportSchedulerService.
- Retention period default = 3 years; adjust to local policy.
- Triggers execute synchronously; high-volume systems should move to async patterns to avoid latency.

## File locations
- Scripts/Audit/
- Scripts/Analytics/
- Scripts/Archival/
- EmployeeLeaveManagment/Services/ReportSchedulerService.cs
- EmployeeLeaveManagment/appsettings.json

