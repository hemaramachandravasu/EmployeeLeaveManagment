# Database Optimization, Partitioning & Operational Analytics — Technical Documentation

## 1. Overview

This module adds **table partitioning**, **advanced index management**, **query optimization helpers**, and **operational analytics** (with Excel/CSV export) on `EmployeeLeaveDb`.

| Capability | Purpose |
|------------|---------|
| Range partitioning | Scale `LeaveRequests` and `AuditLogs` with partition elimination |
| Index management | Covering/filtered indexes, fragmentation analysis, rebuild automation |
| Query optimization | Slow-query review, missing/redundant index helpers, date-window SPs |
| Ops analytics API | Performance, growth, storage, index health, partition inventory |
| Agent jobs | Scheduled index care, stats, health checks, partition SPLIT |

**Deploy package:** `Scripts/Optimization/`  
**API:** `/api/Optimization` (Admin JWT)  
**GitHub:** https://github.com/hemaramachandravasu/EmployeeLeaveManagment

---

## 2. Optimization Strategy

1. **Partition hot transactional tables** by time so date-range reports scan fewer pages.
2. **Align nonclustered indexes** with the partition scheme so `SWITCH` / partition rebuild remain possible.
3. **Keep a non-aligned unique index on identity** (`LeaveRequestId` / `AuditId`) for point lookups.
4. **Maintain indexes by partition** when fragmentation is localized (rebuild one partition, not the whole table).
5. **Push `CreatedDate` / `ChangedOn` predicates** in reporting SPs (`OPTION (RECOMPILE)`) to enable partition elimination and reduce parameter sniffing risk.
6. **Automate** stats updates, health checks, and boundary SPLIT before the rightmost partition fills.

Complementary work already in the Maintenance module (archival, DMV monitors) continues to shrink/observe OLTP growth; partitioning reduces the cost of what remains hot.

---

## 3. Partitioning Design

### 3.1 LeaveRequests — yearly on `CreatedDate`

| Object | Name |
|--------|------|
| Partition function | `PF_LeaveByCreatedDate` (RANGE RIGHT) |
| Partition scheme | `PS_LeaveByCreatedDate` |
| Boundaries | 2024-01-01 … 2028-01-01 |
| Filegroups | `FG_Leave_Pre2024`, `FG_Leave_2024` … `FG_Leave_2027`, `FG_Leave_Future` |
| Clustered PK | `(CreatedDate, LeaveRequestId)` |
| Unique lookup | `UQ_LeaveRequests_LeaveRequestId` (non-aligned) |

**Why `CreatedDate`?** Inserts naturally land in the newest partition; archive/SWITCH targets the oldest partition; most operational reports can filter by creation window.

### 3.2 AuditLogs — quarterly on `ChangedOn`

| Object | Name |
|--------|------|
| Partition function | `PF_AuditByChangedOn` (RANGE RIGHT) |
| Partition scheme | `PS_AuditByChangedOn` |
| Boundaries | Quarterly from 2025-Q1 through 2028-01-01 |
| Filegroups | `FG_Audit_Pre2025`, `FG_Audit_2025_Q1` … `FG_Audit_Future` |
| Clustered PK | `(ChangedOn, AuditId)` |
| Unique lookup | `UQ_AuditLogs_AuditId` (non-aligned) |

**Why quarterly?** Audit volume is higher and more bursty; finer grains keep SWITCH units small.

### 3.3 Migration approach

Scripts `02_Partition_LeaveRequests.sql` and `03_Partition_AuditLogs.sql`:

1. Detect existing partition scheme → skip if already applied  
2. Drop triggers / FKs / NC indexes / PK  
3. Create staging table on the partition scheme  
4. `IDENTITY_INSERT` copy → rename swap → drop old  
5. Recreate aligned covering indexes, FKs, audit trigger, reseeds  

Idempotent and safe to re-run.

### 3.4 Boundary maintenance

| Procedure | Role |
|-----------|------|
| `sp_Opt_SplitLeavePartition` | `NEXT USED` + `SPLIT RANGE` on leave PF |
| `sp_Opt_SplitAuditPartition` | Same for audit PF |
| `sp_Opt_RunScheduledHealthAndPartitionCare` | Health check + auto-SPLIT when near last boundary |

Config metadata: `dbo.PartitionBoundaryConfig`.

---

## 4. Indexing Decisions

| Index | Rationale |
|-------|-----------|
| `IX_LeaveRequests_Employee_StartDate` (aligned) | Employee history / overlap checks |
| `IX_LeaveRequests_Status_StartDate` (aligned) | Pending/approved queues |
| `IX_LeaveRequests_CreatedDate_Status` (aligned) | Partition-friendly status reports |
| `IX_LeaveRequests_ApprovedBy_ApprovedDate` (filtered, aligned) | Approver workload |
| `IX_AuditLogs_Table_ChangedOn` (aligned) | Table-scoped audit trails |
| `IX_AuditLogs_ChangedOn_Action` (aligned) | Action-type analytics with date window |
| `IX_Employees_ManagerId` (filtered) | Hierarchy lookups |
| `IX_Users_UserName_Active` (filtered covering) | Login path |

**Maintenance thresholds** (`sp_Opt_IndexRebuildReorganize`):

- ≥ 30% fragmentation → **REBUILD** (per partition when partitioned)  
- 10–30% → **REORGANIZE**  
- &lt; 10% or &lt; 50 pages → skip  

Supporting SPs: `sp_Opt_IndexFragmentationAnalysis`, `sp_Opt_IndexUsageStats`, `sp_Opt_MissingIndexRecommendations`, `sp_Opt_FindRedundantIndexes`.

---

## 5. Operational Analytics Architecture

```
SQL Agent / Admin API
        │
        ▼
sp_Opt_Report_*  /  sp_Opt_DatabaseHealthCheck
        │
        ▼
OptimizationRepository (ADO.NET)
        │
        ▼
OptimizationController ──► JSON | Excel | CSV
```

| Procedure | Report |
|-----------|--------|
| `sp_Opt_Report_PerformanceSummary` | Size, sessions, blocked requests, partitioned table count |
| `sp_Opt_Report_QueryExecutionStats` | Plan-cache top consumers |
| `sp_Opt_Report_TableGrowth` | Rows / MB / partition count per table |
| `sp_Opt_Report_StorageUtilization` | Filegroup & file space |
| `sp_Opt_Report_IndexHealth` | Partition-aware fragmentation |
| `sp_Opt_Report_PartitionInfo` | Boundary map + rows per partition |

Optimized query helpers: `sp_Opt_GetLeaveHistoryByDateWindow`, `sp_Opt_GetAuditByDateWindow`, `sp_Opt_SlowQueryReview`.

---

## 6. Maintenance Plan (Agent Jobs)

| Job | Schedule | Command |
|-----|----------|---------|
| `ELM_Opt_Index_Maintenance` | Sun 02:30 | `sp_Opt_IndexRebuildReorganize` |
| `ELM_Opt_Statistics_Update` | Daily 03:30 | `sp_Opt_UpdateStatistics` |
| `ELM_Opt_Health_Check` | Daily 06:00 | `sp_Opt_DatabaseHealthCheck` |
| `ELM_Opt_Partition_Manage` | Day 1 monthly 01:00 | `sp_Opt_RunScheduledHealthAndPartitionCare` |
| `ELM_Opt_Performance_Snapshot` | Every 6 hours | Metric snapshot (or performance summary) |

Script: `Scripts/Optimization/07_Agent_Jobs.sql` (requires SQL Server Agent; not on Express).

Run history: `dbo.OptimizationRunLog`.

---

## 7. Deploy Steps

```powershell
# Prerequisite
sqlcmd -S localhost -E -C -i MASTER_DEPLOY.sql

cd Scripts\Optimization
sqlcmd -S localhost -E -C -i OPTIMIZATION_MASTER_DEPLOY.sql
sqlcmd -S localhost -E -C -i 07_Agent_Jobs.sql   # optional
```

Verify:

```sql
EXEC dbo.sp_Opt_Report_PartitionInfo;
EXEC dbo.sp_Opt_Report_PerformanceSummary;
EXEC dbo.sp_Opt_DatabaseHealthCheck;
```

---

## 8. API Endpoints (Admin JWT)

| Method | Route |
|--------|-------|
| GET | `/api/Optimization/performance-summary` |
| GET | `/api/Optimization/reports/query-execution?topN=25` |
| GET | `/api/Optimization/reports/table-growth` |
| GET | `/api/Optimization/reports/storage-utilization` |
| GET | `/api/Optimization/reports/index-health` |
| GET | `/api/Optimization/reports/partition-info?tableName=LeaveRequests` |
| GET | `/api/Optimization/health-check` |
| POST | `/api/Optimization/export/*-excel` and `/export/*-csv` |

Sample exports: `Docs/Samples/Optimization/`.

---

## 9. Recommendations for Future Scalability

1. **SWITCH archival** — Create an empty, schema-matched staging table on the oldest partition’s filegroup and `ALTER TABLE ... SWITCH PARTITION` into archive storage (near-zero logging).  
2. **Dedicated filegroups on separate volumes** — Isolate current-year leave/audit files for I/O balance.  
3. **Sliding window** — Automate MERGE of aged empty partitions after SWITCH.  
4. **Columnstore** on DW `FactLeaveRequests` (already offloaded) for heavier analytics; keep OLTP rowstore partitioned.  
5. **Query Store** — Enable for regression detection after index/partition changes.  
6. **Online rebuilds** — Use `@OnlineRebuild = 1` on Enterprise/Developer editions during business hours.  
7. **Read scale-out** — Route heavy ops reports to a readable secondary if Always On is introduced.

---

## 10. Deliverable Map

| Deliverable | Location |
|-------------|----------|
| Partitioning scripts | `Scripts/Optimization/01–03_*.sql` |
| Index management | `Scripts/Optimization/04_Index_Optimization.sql` |
| Query optimization | `Scripts/Optimization/05_Query_Optimization.sql` |
| Ops analytics SPs | `Scripts/Optimization/06_Ops_Analytics_Procedures.sql` |
| Agent jobs | `Scripts/Optimization/07_Agent_Jobs.sql` |
| Master deploy | `Scripts/Optimization/OPTIMIZATION_MASTER_DEPLOY.sql` |
| ADO.NET API | `Controllers/OptimizationController.cs`, `Data/OptimizationRepository.cs`, `Services/OptimizationService.cs` |
| Samples | `Docs/Samples/Optimization/` |
| This document | `Docs/DATABASE_OPTIMIZATION_PARTITIONING_DOCUMENTATION.md` |
