# Database Capacity Planning, Resource Monitoring & SQL Performance Dashboard

## 1. Overview

This module provides **capacity forecasting**, a **SQL performance dashboard**, **configurable alerting**, and **scheduled metric collection** for `EmployeeLeaveDb`.

| Capability | Purpose |
|------------|---------|
| Capacity planning | Growth trends, table/filegroup size, days-until-full forecast |
| Performance dashboard | Slow queries, trends, index usage, sessions, wait stats, resources |
| Alerting | Storage, volume free space, fragmentation, slow queries, failed jobs, capacity |
| Automation | Agent jobs for capture, refresh, alerts, history archive |
| Exports | Excel / CSV via Admin API |

**Deploy:** `Scripts/CapacityPerformance/`  
**API:** `/api/CapacityPerformance` (Admin JWT)  
**GitHub:** https://github.com/hemaramachandravasu/EmployeeLeaveManagment

---

## 2. Monitoring Architecture

```
SQL Agent jobs
   ├─ CollectMetrics ──► DatabaseMetricSnapshot + CapacityForecastCache
   ├─ RefreshDashboard ──► PerfWaitSnapshot
   ├─ AlertScan ──► OpsAlertLog
   └─ ArchiveHistory ──► retention purge
            │
            ▼
   sp_CapPerf_Dashboard / report SPs
            │
            ▼
   CapacityPerformanceRepository (ADO.NET)
            │
            ▼
   /api/CapacityPerformance  ──► JSON | Excel | CSV
```

New tables: `CapacityAlertThreshold`, `PerfWaitSnapshot`, `CapacityForecastCache`, `CapacityPerfRunLog`.  
Reuses (or creates if missing): `OpsAlertLog`, `DatabaseMetricSnapshot`.

---

## 3. Capacity Planning Methodology

1. Capture periodic size snapshots (`TotalSizeMB`, `UsedSpaceMB`, `UsedPercent`).  
2. Compute average daily growth from lookback history (default 90 days).  
3. Project used space at 30 / 90 days.  
4. Estimate **DaysUntilFull** = free data-file MB ÷ avg daily growth.  
5. Alert when days remaining fall below configured warn/crit thresholds.

Procedure: `sp_Cap_ForecastCapacity` / `POST /api/CapacityPerformance/forecast`.

---

## 4. Performance Metrics

| Metric | Procedure |
|--------|-----------|
| Slow query statistics | `sp_Perf_SlowQueryStatistics` |
| Query execution trends | `sp_Perf_QueryExecutionTrends` |
| Index utilization | `sp_Perf_IndexUtilization` |
| Active sessions | `sp_Perf_ActiveSessions` |
| Wait statistics | `sp_Perf_WaitStatistics` |
| Resource summary | `sp_Perf_ResourceConsumptionSummary` |
| Unified dashboard | `sp_CapPerf_Dashboard` |

---

## 5. Alert Configuration

Thresholds in `CapacityAlertThreshold` (editable via API):

| Code | Default warn / crit |
|------|---------------------|
| `STORAGE_USED_PCT` | 80 / 90 % |
| `VOLUME_FREE_PCT` | 15 / 10 % free |
| `INDEX_FRAG_PCT` | 30 / 50 % |
| `LONG_QUERY_SEC` | 60 / 180 s |
| `CAPACITY_DAYS_LEFT` | 90 / 30 days |
| `WAIT_PCT` | 25 / 40 % |

Scan: `sp_CapPerf_RunAllAlerts` / `POST /api/CapacityPerformance/alerts/scan`.  
Acknowledge: `POST /api/CapacityPerformance/alerts/{id}/acknowledge`.

---

## 6. Agent Jobs

| Job | Schedule |
|-----|----------|
| `ELM_CapPerf_CollectMetrics` | Every 6 hours |
| `ELM_CapPerf_RefreshDashboard` | Every 2 hours |
| `ELM_CapPerf_AlertScan` | Every 2 hours |
| `ELM_CapPerf_ArchiveHistory` | Weekly Sun 05:00 |

---

## 7. Deploy

```powershell
cd C:\Users\harim\Downloads\EmployeeLeaveManagment\Scripts\CapacityPerformance
sqlcmd -S localhost -E -C -I -i CAPACITY_PERFORMANCE_MASTER_DEPLOY.sql
sqlcmd -S localhost -E -C -i 06_Agent_Jobs.sql   # optional (needs Agent)
```

Verify:

```sql
EXEC dbo.sp_Cap_CaptureMetricSnapshot;
EXEC dbo.sp_CapPerf_Dashboard;
EXEC dbo.sp_CapPerf_RunAllAlerts;
```

---

## 8. Operational Recommendations

1. Keep metric snapshots for ≥ 90 days before forecasting.  
2. Treat `DaysUntilFull` as directional — validate with filegrowth and volume free space.  
3. Pair fragmentation alerts with weekly index maintenance (`ELM_Opt_Index_Maintenance`).  
4. Investigate top waits (`PAGEIOLATCH_*`, `LCK_M_*`, `CXPACKET`) before adding hardware.  
5. Acknowledge alerts after remediation to keep open-alert noise low.

---

## 9. Future Scalability

1. Query Store baselines and regression alerts.  
2. Always On secondary for read-only dashboard offload.  
3. Per-filegroup growth forecasts after partitioning.  
4. SIEM webhook for Critical alerts.  
5. ML-based seasonal capacity models.

---

## 10. Deliverable Map

| Item | Path |
|------|------|
| Scripts | `Scripts/CapacityPerformance/*.sql` |
| API | `Controllers/CapacityPerformanceController.cs` |
| Docs | `Docs/DATABASE_CAPACITY_PERFORMANCE_DOCUMENTATION.md` |
| Samples | `Docs/Samples/CapacityPerformance/` |
