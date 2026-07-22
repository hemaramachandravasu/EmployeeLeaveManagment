# Database Auditing, Data Integrity & Compliance — Technical Documentation

## 1. Overview

This module adds a **database auditing**, **business-rule integrity validation**, and **compliance reporting** framework on `EmployeeLeaveDb`.

| Capability | Purpose |
|------------|---------|
| DML auditing | Insert / Update / Delete trail on critical tables via `AuditLogs` |
| User activity | Application action log (`UserActivityLog`) for admin review |
| Integrity checks | Balance, overlaps, orphan FKs, holidays, leave policies |
| Compliance reports | Violations, audit summary, data quality, user activity |
| Monitoring | Failed runs, exceptions, Agent job history, compliance status |
| Exports | Excel / CSV via Admin API |

**Deploy package:** `Scripts/AuditIntegrity/`  
**API:** `/api/AuditIntegrity` (Admin JWT)  
**GitHub:** https://github.com/hemaramachandravasu/EmployeeLeaveManagment

---

## 2. Auditing Strategy

### 2.1 Row-change audit (`AuditLogs`)

Triggers write JSON before/after snapshots with `ChangedBy = SUSER_SNAME() | APP_NAME()`:

| Table | Trigger |
|-------|---------|
| Employees | `trg_Employees_Audit` (core + ensured by this module) |
| LeaveRequests | `trg_LeaveRequests_Audit` |
| Users | `trg_Users_Audit` |
| Departments | `trg_Departments_Audit` |
| LeaveTypes | `trg_LeaveTypes_Audit` |
| Roles | `trg_Roles_Audit` |
| LeaveBalances | `trg_LeaveBalances_Audit` |
| Holidays | `trg_Holidays_Audit` |
| LeavePolicies | `trg_LeavePolicies_Audit` |

Helpers: `sp_Audit_Write`, `sp_Audit_LogException`.

### 2.2 User activity

`sp_Audit_LogUserActivity` / `POST /api/AuditIntegrity/user-activity` records Login, Export, Approve, Apply, Config, etc., with optional IP and success flag.

### 2.3 Retention

Agent job `ELM_Audit_Activity_Retention` (weekly) purges:

- `UserActivityLog` older than 180 days  
- `DatabaseExceptionLog` older than 90 days  
- Resolved Low/Medium integrity findings older than 90 days  

Row-change `AuditLogs` continue to use the existing Maintenance archival path.

---

## 3. Integrity Validation Rules

| Check code | Severity | Rule |
|------------|----------|------|
| `BALANCE_MISMATCH` | High | `LeaveBalances.UsedDays` ≠ sum of approved leave days for emp/type/year |
| `BALANCE_MISSING` | Medium | Approved leave exists without a current balance row |
| `DUPLICATE_OVERLAP` | Critical | Overlapping Pending/Approved leave for the same employee |
| `ORPHAN_FK` | Critical–Medium | Broken references (Employees, LeaveTypes, Roles, Manager, etc.) |
| `HOLIDAY_MAPPING` | Medium | Leave spans a non-optional holiday while policy `ExcludeHolidays = 1` |
| `POLICY_MAX_DAYS` | High | `TotalDays` exceeds `MaxConsecutiveDays` |
| `POLICY_NOTICE` | Medium | Created→StartDate notice &lt; `MinNoticeDays` |
| `POLICY_MAX_REQUESTS` | High | Requests per year exceed `MaxRequestsPerYear` |

Orchestrator: `sp_Integrity_RunAllChecks` → findings in `IntegrityViolationLog`, run metadata in `ComplianceRunLog`.

Supporting tables:

- **Holidays** — company calendar (seeded sample public holidays)  
- **LeavePolicies** — type-specific + general (`POL_GENERAL`, `POL_CASUAL`, `POL_SICK`)

---

## 4. Compliance Reporting

| Procedure | Report |
|-----------|--------|
| `sp_Report_IntegrityViolations` | Open/closed findings with severity filter |
| `sp_Report_AuditSummary` | DML counts by table + action |
| `sp_Report_DataQualityStatus` | Aggregate health score |
| `sp_Report_UserActivitySummary` | Activity by user + type |
| `sp_Monitor_ComplianceStatus` | Compliant / AttentionRequired / NonCompliant |

Resolve findings: `sp_Compliance_ResolveViolation` / `POST .../violations/{id}/resolve`.

---

## 5. Monitoring & Agent Jobs

| Job | Schedule | Action |
|-----|----------|--------|
| `ELM_Compliance_Integrity_Checks` | Daily 05:00 | `sp_Compliance_RunScheduledAuditJob` |
| `ELM_Compliance_Status_Monitor` | Every 6 hours | Compliance status snapshot |
| `ELM_Audit_Activity_Retention` | Sun 04:30 | Retention cleanup |

Also: `sp_Monitor_FailedValidationChecks`, `sp_Monitor_DatabaseExceptions`, `sp_Monitor_ScheduledAuditJobs`.

---

## 6. Deploy

```powershell
sqlcmd -S localhost -E -C -i MASTER_DEPLOY.sql
# optional but recommended for LeaveBalances:
sqlcmd -S localhost -E -C -i Scripts\Maintenance\MAINTENANCE_MASTER_DEPLOY.sql

cd Scripts\AuditIntegrity
sqlcmd -S localhost -E -C -i AUDIT_INTEGRITY_MASTER_DEPLOY.sql
sqlcmd -S localhost -E -C -i 06_Agent_Jobs.sql   # optional
```

Verify:

```sql
EXEC dbo.sp_Integrity_RunAllChecks;
EXEC dbo.sp_Report_DataQualityStatus;
EXEC dbo.sp_Monitor_ComplianceStatus;
```

---

## 7. API Endpoints (Admin JWT)

| Method | Route |
|--------|-------|
| POST | `/api/AuditIntegrity/run-checks` |
| GET | `/api/AuditIntegrity/compliance-status` |
| GET | `/api/AuditIntegrity/reports/integrity-violations` |
| GET | `/api/AuditIntegrity/reports/audit-summary` |
| GET | `/api/AuditIntegrity/reports/data-quality` |
| GET | `/api/AuditIntegrity/reports/user-activity` |
| GET | `/api/AuditIntegrity/monitor/failed-validations` |
| GET | `/api/AuditIntegrity/monitor/exceptions` |
| GET | `/api/AuditIntegrity/monitor/scheduled-jobs` |
| POST | `/api/AuditIntegrity/violations/{id}/resolve` |
| POST | `/api/AuditIntegrity/user-activity` |
| POST | `/api/AuditIntegrity/export/*-excel` and `/*-csv` |

Sample exports: `Docs/Samples/AuditIntegrity/`.

---

## 8. Future Enhancements

1. Enforce overlap/policy checks inside `sp_ApplyLeave` / `sp_ApproveLeave` (block or warn).  
2. Auto-reconcile `LeaveBalances.UsedDays` from approved leave on a schedule.  
3. Capture application user via `SESSION_CONTEXT` in triggers (not only SQL login).  
4. CDC or temporal tables for high-churn entities.  
5. SIEM export of Critical violations.  
6. Region-aware holiday calendars per department/location.  
7. Working-day leave calculation (exclude weekends + holidays from `TotalDays`).

---

## 9. Deliverable Map

| Deliverable | Location |
|-------------|----------|
| Schema | `Scripts/AuditIntegrity/01_AuditIntegrity_Schema.sql` |
| Triggers / activity | `Scripts/AuditIntegrity/02_Auditing_Triggers.sql` |
| Validation SPs | `Scripts/AuditIntegrity/03_Integrity_Validation_Procedures.sql` |
| Compliance reports | `Scripts/AuditIntegrity/04_Compliance_Report_Procedures.sql` |
| Monitoring | `Scripts/AuditIntegrity/05_Monitoring_Procedures.sql` |
| Agent jobs | `Scripts/AuditIntegrity/06_Agent_Jobs.sql` |
| Master deploy | `Scripts/AuditIntegrity/AUDIT_INTEGRITY_MASTER_DEPLOY.sql` |
| ADO.NET API | `Controllers/AuditIntegrityController.cs`, `Data/AuditIntegrityRepository.cs` |
| Samples | `Docs/Samples/AuditIntegrity/` |
| This document | `Docs/DATABASE_AUDITING_INTEGRITY_COMPLIANCE_DOCUMENTATION.md` |
