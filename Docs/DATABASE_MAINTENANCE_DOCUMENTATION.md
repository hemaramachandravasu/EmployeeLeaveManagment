# Database Archival, Performance Optimization & Health Monitoring — Technical Documentation

## 1. Overview

This module adds a **database maintenance framework** on `EmployeeLeaveDb` covering:

| Capability | Purpose |
|------------|---------|
| Historical archival | Move aged OLTP rows to archive tables without data loss |
| Performance monitoring | Collect slow queries, growth, fragmentation, blocking, deadlocks |
| Automated maintenance | Index care, statistics, cleanup, integrity checks via Agent jobs |
| Health dashboard API | ADO.NET endpoints for size, connections, archive & job history |
| Performance reports | Growth, index health, query, archive, and maintenance reports (Excel/CSV) |

---

## 2. Database Archival Strategy

### Entities

| Entity | Source | Archive table | Default retention | Eligibility |
|--------|--------|---------------|-------------------|-------------|
| Closed leave requests | `LeaveRequests` | `LeaveRequestsArchive` | 730 days | Status `Approved`/`Rejected` and `EndDate` past cutoff |
| Notifications | `Notifications` | `NotificationsArchive` | 180 days | `IsRead = 1` and `CreatedAt` past cutoff |
| Audit logs | `AuditLogs` | `AuditLogsArchive` | 365 days | `ChangedOn` past cutoff |
| Leave balances | `LeaveBalances` | `LeaveBalancesArchive` | 730 days | `IsHistorical = 1` and closed/created past cutoff |

Retention is stored in `dbo.ArchiveRetentionConfig` and can be changed via `sp_Archive_UpdateRetention` or `PUT /api/Maintenance/retention` (minimum 30 days).

### Secure move (no data loss)

Each archive procedure:

1. Starts an `ArchiveRunLog` row with a shared `ArchiveBatchId`
2. Inserts eligible rows into the archive table inside a transaction
3. Deletes only rows that exist in that batch
4. Commits and marks the run `Success` (or rolls back and marks `Failed`)

### Restoration

| Procedure | Key |
|-----------|-----|
| `sp_Restore_LeaveRequests` | `@ArchiveBatchId` and/or `@LeaveRequestId` |
| `sp_Restore_Notifications` | `@ArchiveBatchId` and/or `@NotificationId` |
| `sp_Restore_AuditLogs` | `@ArchiveBatchId` and/or `@AuditId` |
| `sp_Restore_LeaveBalances` | `@ArchiveBatchId` and/or `@LeaveBalanceId` |

Restore uses `IDENTITY_INSERT` to preserve original keys, then removes restored rows from the archive.

**Orchestrator:** `sp_Archive_RunAll` / `sp_Maint_RunArchiveJob`

---

## 3. Monitoring Architecture

```
SQL Agent / manual EXEC
        │
        ▼
sp_Monitor_CaptureMetricSnapshot ──► DatabaseMetricSnapshot
        │
        ▼
sp_Monitor_* (live DMVs) ──► API (MaintenanceRepository)
        │
        ▼
sp_Report_* ──► Excel / CSV exports
```

| Procedure | Metrics |
|-----------|---------|
| `sp_Monitor_SlowRunningQueries` | Active requests over elapsed threshold |
| `sp_Monitor_DatabaseGrowth` | Data/log/used/free size |
| `sp_Monitor_TableGrowth` | Per-table rows and space |
| `sp_Monitor_IndexFragmentation` | Fragmentation + rebuild/reorganize advice |
| `sp_Monitor_BlockingSessions` | Blocker / blocked pairs |
| `sp_Monitor_DeadlockStatistics` | Perf counters + system_health XEvent (best-effort) |
| `sp_Monitor_ActiveConnections` | Session counts and detail |
| `sp_Monitor_HealthDashboard` | Multi-result dashboard feed for the API |

---

## 4. Performance Optimization Techniques

1. **Index maintenance** — Rebuild at ≥30% fragmentation; reorganize at 10–30% (`sp_Maint_IndexOptimize`)
2. **Statistics** — Fullscan update on all user tables (`sp_Maint_UpdateStatistics`)
3. **Archival** — Shrinks hot OLTP tables so indexes and plans stay efficient
4. **Temp cleanup** — Prunes metric snapshots, old logs, stale unread notifications
5. **Integrity** — Weekly `DBCC CHECKDB` via `sp_Maint_IntegrityCheck`
6. **Metric history** — Periodic snapshots enable growth trending without scanning files every report

---

## 5. Maintenance Job Design

| Agent job | Schedule | Command |
|-----------|----------|---------|
| `ELM_Integrity_Check` | Sun 01:00 | `sp_Maint_IntegrityCheck` |
| `ELM_Index_Maintenance` | Sun 02:00 | `sp_Maint_IndexOptimize` |
| `ELM_Statistics_Update` | Daily 03:00 | `sp_Maint_UpdateStatistics` |
| `ELM_Archive_Execution` | Day 1 monthly 04:00 | `sp_Maint_RunArchiveJob` |
| `ELM_Temp_Cleanup` | Sat 05:00 | `sp_Maint_TempDataCleanup` |
| `ELM_Metric_Snapshot` | Every 6 hours | `sp_Monitor_CaptureMetricSnapshot` |

All jobs write to `MaintenanceRunLog`. Requires SQL Server Agent (not on Express).

**Script:** `Scripts/Maintenance/06_Agent_Jobs.sql`

---

## 6. Recovery Considerations

- Archive is **copy-then-delete** in one transaction — a failure leaves OLTP intact
- Restore by batch or primary key; conflicts are skipped if the live row already exists
- Keep regular full/diff SQL backups of `EmployeeLeaveDb` (archive tables are in the same database)
- For long-term cold storage, optionally back up and detach archive tables to a separate archive DB (future enhancement)
- After restore of leave requests, re-run DW ETL if analytics must reflect restored history

---

## 7. API Surface (Admin JWT)

| Endpoint | Purpose |
|----------|---------|
| `GET /api/Maintenance/health` | Full health dashboard |
| `GET /api/Maintenance/database-size` | Size / utilization |
| `GET /api/Maintenance/retention` | Retention config |
| `PUT /api/Maintenance/retention` | Update retention |
| `GET /api/Maintenance/reports/monthly-growth` | Growth report |
| `GET /api/Maintenance/reports/index-health` | Index health |
| `GET /api/Maintenance/reports/query-performance` | Query stats |
| `GET /api/Maintenance/reports/archive-summary` | Archive summary |
| `GET /api/Maintenance/reports/maintenance-execution` | Job history |
| `POST /api/Maintenance/export/*-excel` | Excel exports |
| `POST /api/Maintenance/export/*-csv` | CSV exports |

**ADO.NET:** `MaintenanceRepository` → `MaintenanceService` → `MaintenanceController`

---

## 8. Deployment

```powershell
# 1. Operational database
sqlcmd -S localhost -E -C -i MASTER_DEPLOY.sql

# 2. Maintenance module
cd Scripts\Maintenance
sqlcmd -S localhost -E -C -i MAINTENANCE_MASTER_DEPLOY.sql

# 3. Optional Agent jobs
sqlcmd -S localhost -E -C -i 06_Agent_Jobs.sql
```

---

## 9. Future Enhancement Recommendations

- **Implemented:** OLTP partitioning for `LeaveRequests` / `AuditLogs` — see [DATABASE_OPTIMIZATION_PARTITIONING_DOCUMENTATION.md](DATABASE_OPTIMIZATION_PARTITIONING_DOCUMENTATION.md)
- Partition-SWITCH archival into `LeaveRequestsArchive` / `AuditLogsArchive` for near-zero-cost moves
- Move archives to a dedicated `EmployeeLeaveArchive` database / filegroup
- Extended Events session dedicated to deadlocks with alerting
- Query Store baselines and regressions surfaced in the health API
- Online index rebuild where Enterprise edition is available (`sp_Opt_IndexRebuildReorganize @OnlineRebuild = 1`)
- Automated ticket creation when fragmentation or free space crosses thresholds

---

## 10. File Inventory

| File | Description |
|------|-------------|
| `Scripts/Maintenance/01_Archive_Schema.sql` | Archive tables, retention, logs |
| `Scripts/Maintenance/02_Archive_Procedures.sql` | Archive / restore SPs |
| `Scripts/Maintenance/03_Monitoring_Procedures.sql` | DMV monitoring SPs |
| `Scripts/Maintenance/04_Maintenance_Procedures.sql` | Index, stats, cleanup, CHECKDB |
| `Scripts/Maintenance/05_Report_Procedures.sql` | Report SPs |
| `Scripts/Maintenance/06_Agent_Jobs.sql` | SQL Server Agent jobs |
| `Scripts/Maintenance/MAINTENANCE_MASTER_DEPLOY.sql` | Combined deploy |
| `Docs/Samples/Maintenance/*.csv` | Sample report exports |
| `EmployeeLeaveManagment/Data/MaintenanceRepository.cs` | ADO.NET repository |
| `EmployeeLeaveManagment/Controllers/MaintenanceController.cs` | REST API |

## 11. Repository

https://github.com/hemaramachandravasu/EmployeeLeaveManagment
