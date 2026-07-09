# Data Warehouse & Analytics Module — Technical Documentation

## 1. Overview

This module adds a **separate analytical database** (`EmployeeLeaveDW`) using a lightweight **star schema**. Historical leave data is extracted nightly from the operational `EmployeeLeaveDb`, transformed, and loaded via T-SQL stored procedures. Predictive and trend reports, dashboard feeds, and Excel/CSV exports are exposed through the ASP.NET Core API using ADO.NET.

| Database | Role |
|----------|------|
| `EmployeeLeaveDb` | Operational OLTP (leave transactions, employees) |
| `EmployeeLeaveDW` | Read-heavy analytics warehouse (star schema) |

---

## 2. Star Schema Design Rationale

### Fact Table: `FactLeaveRequests`

**Grain:** One row per leave request.

| Measure | Description |
|---------|-------------|
| `DaysRequested` | Total days on the request |
| `DaysApproved` | Days counted when status = Approved |
| `DaysRejected` | Days counted when status = Rejected |

Foreign keys link to `DimEmployee`, `DimDepartment`, `DimLeaveType`, and `DimDate` (start, end, request dates).

### Dimension Tables

| Table | Purpose |
|-------|---------|
| `DimDate` | Calendar attributes (year, quarter, month, week, weekend flag) |
| `DimDepartment` | Department attributes with SCD Type 2 versioning |
| `DimLeaveType` | Leave type catalog with SCD Type 2 |
| `DimEmployee` | Employee attributes with department linkage and SCD Type 2 |

**Why a separate database?**

- Isolates analytical workloads from transactional CRUD
- Enables indexed star-schema queries without impacting OLTP performance
- Supports incremental ETL and historical versioning (SCD Type 2)

**Script location:** `Scripts/DataWarehouse/01_DW_Schema.sql`

---

## 3. ETL Pipeline Architecture

### Orchestration

```
sp_ETL_RunNightly
  ├── sp_ETL_LoadDimDate
  ├── sp_ETL_LoadDimDepartment
  ├── sp_ETL_LoadDimLeaveType
  ├── sp_ETL_LoadDimEmployee
  └── sp_ETL_LoadFactLeaveRequests
```

### Incremental Load Strategy

| Layer | Strategy |
|-------|----------|
| Dimensions | SCD Type 2 — close current row, insert new version on attribute change |
| Facts | MERGE on `SourceLeaveRequestId`; load new records where `CreatedDate > last successful run`, plus re-sync rows with status/day changes |

### Logging

All ETL steps write to `dbo.ETL_RunLog`:

| Column | Description |
|--------|-------------|
| `ProcessName` | Step name (e.g. `FactLeaveRequests`, `NightlyETL`) |
| `StartTime` / `EndTime` | Run timestamps |
| `Status` | `Running`, `Success`, or `Failed` |
| `RowsInserted` / `RowsUpdated` | Row counts per step |
| `ErrorMessage` | Populated on failure |

### Scheduling

SQL Server Agent job `ELM_Nightly_DW_ETL` runs daily at **01:00**.

**Script:** `Scripts/DataWarehouse/04_Agent_Job.sql`

### Deployment

```powershell
# 1. Deploy operational DB (if not already)
sqlcmd -S localhost -E -i MASTER_DEPLOY.sql

# 2. Deploy data warehouse + run initial ETL
cd Scripts\DataWarehouse
sqlcmd -S localhost -E -i 01_DW_Schema.sql
sqlcmd -S localhost -E -i 02_ETL_Procedures.sql
sqlcmd -S localhost -E -i 03_Analytics_Procedures.sql
sqlcmd -S localhost -E -i DW_MASTER_DEPLOY.sql

# 3. (Optional) Schedule nightly job
sqlcmd -S localhost -E -i 04_Agent_Job.sql
```

---

## 4. Predictive Report Methodology & Assumptions

### Forecasted Leave Demand (`sp_ForecastLeaveDemand_Department`)

- **Method:** Rolling 12-month average of monthly leave counts per department
- **Horizon:** Next 3 calendar months from `@AsOfDate`
- **Assumption:** Future demand resembles recent historical average (no seasonality decomposition)

### Employee Burnout Risk (`sp_EmployeeBurnoutRisk`)

- **Lookback:** Default 180 days (configurable)
- **Signals:**
  - Long consecutive leave blocks (≥ 10 days)
  - High frequency + volume (≥ 6 leaves and ≥ 20 days)
  - Unusual recent frequency (≥ 3 leaves in last 90 days)
- **Output:** Risk level (`High`, `Medium`, `Low`) with reason text

### Peak Leave Periods (`sp_PeakLeavePeriods`)

- **Method:** Rank months and weeks by approved leave count over last N years
- **Default:** Top 10 periods per granularity

---

## 5. Dashboard Data Feeds (API)

All endpoints require **Admin JWT** (`Authorization: Bearer <token>`).

| Endpoint | Stored Procedure | Purpose |
|----------|------------------|---------|
| `GET /api/DataWarehouse/forecast-demand` | `sp_ForecastLeaveDemand_Department` | 3-month forecast by department |
| `GET /api/DataWarehouse/burnout-risk` | `sp_EmployeeBurnoutRisk` | Burnout risk indicators |
| `GET /api/DataWarehouse/peak-periods` | `sp_PeakLeavePeriods` | Peak months/weeks |
| `GET /api/DataWarehouse/month-over-month-trend` | `sp_DW_MonthOverMonthTrend` | MoM trend with % change |
| `GET /api/DataWarehouse/department-heatmap` | `sp_DW_DepartmentUtilizationHeatmap` | Dept × month utilization |
| `GET /api/DataWarehouse/top-leave-types` | `sp_DW_TopLeaveTypesByVolume` | Top 5 leave types (current year) |
| `GET /api/DataWarehouse/etl-log` | Inline query on `ETL_RunLog` | Recent ETL runs |

### Export Endpoints

| Endpoint | Format |
|----------|--------|
| `POST /api/DataWarehouse/export/forecast-demand-excel` | `.xlsx` (Summary + Detail tabs) |
| `POST /api/DataWarehouse/export/burnout-risk-excel` | `.xlsx` |
| `POST /api/DataWarehouse/export/peak-periods-excel` | `.xlsx` |
| `POST /api/DataWarehouse/export/mom-trend-excel` | `.xlsx` |
| `POST /api/DataWarehouse/export/forecast-demand-csv` | `.csv` |
| `POST /api/DataWarehouse/export/burnout-risk-csv` | `.csv` |
| `POST /api/DataWarehouse/export/peak-periods-csv` | `.csv` |
| `POST /api/DataWarehouse/export/mom-trend-csv` | `.csv` |

**ADO.NET layer:** `DataWarehouseRepository` → `DataWarehouseService` → `DataWarehouseController`

**Connection string:** `DataWarehouseConnection` in `appsettings.json`

---

## 6. Known Limitations

1. **Forecasting** uses simple rolling averages — no ARIMA, regression, or ML models
2. **No seasonality adjustment** for holidays or organizational events
3. **Fact incremental load** relies on `CreatedDate`; status changes on older records are re-synced via change detection but there is no `ModifiedDate` on the OLTP table
4. **Small sample data** in seed scripts may produce sparse analytics until more history is loaded
5. **Agent job** requires SQL Server Agent (not available on Express edition)

---

## 7. Future Enhancements

- Add `ModifiedDate` to `LeaveRequests` for cleaner incremental fact updates
- Introduce `FactEmployeeSnapshot` for headcount/capacity planning
- Replace rolling average with exponential smoothing or ML-based forecasting
- Add SSIS / Azure Data Factory orchestration for enterprise deployments
- Materialized aggregate tables for sub-second dashboard response at scale
- Row-level security on warehouse views mirroring operational RLS policies

---

## 8. File Inventory

| File | Description |
|------|-------------|
| `Scripts/DataWarehouse/01_DW_Schema.sql` | Star schema DDL |
| `Scripts/DataWarehouse/02_ETL_Procedures.sql` | ETL stored procedures |
| `Scripts/DataWarehouse/03_Analytics_Procedures.sql` | Predictive + dashboard SPs |
| `Scripts/DataWarehouse/04_Agent_Job.sql` | SQL Server Agent job |
| `Scripts/DataWarehouse/DW_MASTER_DEPLOY.sql` | Combined deploy + initial load |
| `Docs/Samples/ETL_RunLog_Sample.csv` | Sample ETL log output |
| `Docs/Samples/ForecastLeaveDemand_Sample.csv` | Sample forecast CSV |
| `EmployeeLeaveManagment/Data/DataWarehouseRepository.cs` | ADO.NET repository |
| `EmployeeLeaveManagment/Controllers/DataWarehouseController.cs` | REST API controller |
