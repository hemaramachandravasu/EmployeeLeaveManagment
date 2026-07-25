# Reporting, Audit Trail, and Archival Design

## Audit Trail Design
- Central table: `dbo.AuditLogs` captures TableName, RecordId, ActionType (Insert/Update/Delete), OldValue (JSON), NewValue (JSON), ChangedBy, ChangedOn.
- Triggers:
  - `trg_Employees_Audit`
  - `trg_LeaveRequests_Audit`
  - `trg_Users_Audit` (password hashes redacted as `***` in JSON payloads)
- Application may set SESSION_CONTEXT prior to DML so ChangedBy can reflect the real app user where configured.
- For very high write-throughput, consider an asynchronous pipeline (Service Broker / queue) to write audits off the critical path.

## Analytics Queries
- Stored procedures (also under `Scripts/Analytics/` legacy names):
  - `sp_LeaveTrendAnalysis` / `sp_GetLeaveTrend` — month-over-month totals
  - `sp_DepartmentComparison` / `sp_GetDepartmentComparison` — per-department aggregates
  - `sp_FrequentLeavePattern` / `sp_GetFrequentLeavePatterns` — top employees by leave volume
  - `sp_ForecastLeaveUtilization` / `sp_GetForecastedLeaveUtilization` — historical-average forecast
- Heavy aggregations stay on the DB side for performance and network efficiency.
- Admin API: `/api/Analytics/*`

## Scheduling / Automation
- `ReportSchedulerService` (.NET `BackgroundService`) auto-generates **CSV and Excel (.xlsx)** reports on the interval in `Reporting:IntervalHours`.
- Output folder: `Reporting:OutputFolder` (default `C:\Reports`).
- Each run writes department stats, monthly utilization, leave trend, department comparison, frequent leave pattern, and forecast files.
- Alternative: SQL Server Agent jobs (`Scripts/Maintenance/06_Agent_Jobs.sql`) for archival/maintenance schedules.

## Archival Strategy
- Closed leave requests move to `dbo.LeaveRequestsArchive` via Maintenance module (`sp_Maint_RunArchiveJob` / Agent job `ELM_Archive_Execution`).
- Criteria and restore paths: see `Docs/DATABASE_MAINTENANCE_DOCUMENTATION.md`.
- Large datasets: optional partitioning for `LeaveRequests` / `AuditLogs` (Optimization module).

## Indexing & Performance
- `AuditLogs`: `IX_AuditLogs_Table_ChangedOn`, `IX_AuditLogs_RecordId`
- Leave history: `IX_LeaveRequests_Employee_StartDate`, `IX_LeaveRequests_Status_StartDate`
- Use Query Store / actual execution plans to validate analytics SPs under load.

## Operational Notes
- Grant the application DB user INSERT on `dbo.AuditLogs` and EXECUTE on analytics SPs.
- Deploy triggers to non-production first and validate payload size/latency.

## Assumptions and Limitations
- Audit triggers run synchronously on the same transaction as the DML — high-volume systems may prefer async audit.
- Users audit stores redacted password hashes only.
- Scheduler interval defaults to 24 hours; adjust in `appsettings.json`.
- Retention defaults (Maintenance module) may differ from older “3 years” notes; configure via `ArchiveRetentionConfig`.

## Sample outputs
- Analytics: `Docs/Samples/Analytics/`
- Reporting (Task 2): `Docs/Samples/Reporting/`

## File locations
- `MASTER_DEPLOY.sql` (audit + analytics SPs)
- `Scripts/Audit/`, `Scripts/Analytics/`, `Scripts/Archival/`
- `Scripts/Database/Task3_Users_Audit_Trigger.sql`
- `EmployeeLeaveManagment/Services/ReportSchedulerService.cs`
- `EmployeeLeaveManagment/Controllers/AnalyticsController.cs`
- `EmployeeLeaveManagment/appsettings.json`

