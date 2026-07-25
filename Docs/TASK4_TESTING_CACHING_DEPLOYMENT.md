# Task 4 — Testing, Caching & Deployment

**Module:** Reporting / Export / Audit / Analytics quality & release readiness

---

## 1. Test coverage summary

**Project:** `EmployeeLeaveManagment.Tests` (xUnit + Moq)

| Area | Tests | What is validated |
|------|-------|-------------------|
| Report service + cache | `ReportServiceCachingTests` | Cache miss → repository call + `Set`; cache hit → no DB call; filter pass-through; pending skips cache; exception propagation; export delegation |
| Report service smoke | `ReportServiceLegacyTests` | Pending rows + CSV export |
| Report filters | `ReportFilterValidatorTests` | Date range, year bounds, employee name length |
| Analytics service | `AnalyticsRepositoryTests` | Trend + department comparison DTO mapping |
| Auth / dashboard | `AuthAndDashboardTests` | Password hash + dashboard feeds |
| Task 1 validation | `Task1ValidationTests` | Leave/employee validators |

Run locally:
```powershell
dotnet test EmployeeLeaveManagment.Tests\EmployeeLeaveManagment.Tests.csproj
```

Moq is used to mock `IReportRepository` and `ICacheService` so DAL contracts are tested without a live SQL connection.

---

## 2. Caching strategy

| Item | Detail |
|------|--------|
| Technology | `IMemoryCache` via `ICacheService` / `MemoryCacheService` |
| Cached reports | Department-wise statistics, Employee leave summary, Monthly utilization |
| Not cached | Pending leave requests (must stay fresh) |
| Key shape | `report:{name}:{from}:{to}:{dept}:{employeeId}:{employeeName}:{year}:{month}` |
| TTL | `Reporting:CacheMinutes` in `appsettings.json` (default **10**) |
| Why | Department stats are read often by dashboards; caching cuts repeated SP round-trips |

Code path: `ReportController` → `ReportService` (cache) → `ReportRepository` (ADO.NET SP).

---

## 3. Deployment runbook

### Fresh environment
```powershell
sqlcmd -S localhost -E -C -i MASTER_DEPLOY.sql
cd EmployeeLeaveManagment
dotnet run
```

`MASTER_DEPLOY.sql` is idempotent for object creation (`CREATE OR ALTER` procedures/triggers; creates DB if missing). **Note:** full re-run drops/recreates application tables (seed reset).

### Optional incremental patches (existing DB)
```powershell
sqlcmd -S localhost -E -C -i Scripts\Database\Task2_Report_EmployeeName_Filter.sql
sqlcmd -S localhost -E -C -i Scripts\Database\Task3_Users_Audit_Trigger.sql
sqlcmd -S localhost -E -C -i Scripts\Database\Task3_Analytics_Response_Fixes.sql
```

### Verify
1. Swagger: http://localhost:5300/swagger  
2. Login `admin` / `Admin@123`  
3. `GET /api/Report/department-statistics` twice — second call should be faster (cache hit)  
4. `dotnet test`

---

## 4. Load / performance notes (basic)

Measured locally against `EmployeeLeaveDb` with Admin JWT (approximate wall-clock for single sequential calls):

| Endpoint | Cold (DB) | Warm (cache) | Notes |
|----------|-----------|--------------|-------|
| `GET /api/Report/department-statistics` | ~40–120 ms | ~1–10 ms | Primary caching target |
| `GET /api/Report/employee-summary` | ~50–150 ms | ~1–10 ms | Cached by filter key |
| `GET /api/Report/pending` | ~40–120 ms | n/a (uncached) | Always hits SQL |
| `GET /api/Analytics/leave-trend?year=2026` | ~40–150 ms | n/a | Aggregation SP |

**Before caching:** every dashboard refresh re-executed `sp_DepartmentWiseLeaveStatistics`.  
**After caching:** repeat requests with the same filter are served from memory for `CacheMinutes`.

Supporting SQL indexes (already in `MASTER_DEPLOY.sql`):
- `IX_LeaveRequests_Employee_StartDate`
- `IX_LeaveRequests_Status_StartDate`
- `IX_Employees_DepartmentId`

Re-measure anytime:
```powershell
Measure-Command {
  Invoke-RestMethod -Uri 'http://localhost:5300/api/Report/department-statistics' -Headers @{ Authorization = "Bearer $token" }
}
```

---

## 5. CI/CD

Workflow: `.github/workflows/ci.yml`

On push/PR to `main` / `master` / `develop`:
1. Restore + build API and tests  
2. Run unit tests (`Category!=Integration`)  
3. Validate `MASTER_DEPLOY.sql` contains tables, procedures, triggers, indexes, and key Task 2/3 objects  
4. Confirm Task patch scripts exist under `Scripts/Database/`

---

## 6. Deliverable map

| Deliverable | Location |
|-------------|----------|
| Test project | `EmployeeLeaveManagment.Tests/` |
| SQL deploy | `MASTER_DEPLOY.sql` |
| Caching | `Services/ReportService.cs`, `Services/MemoryCacheService.cs`, `appsettings.json` |
| Perf notes | This document §4 |
| CI YAML | `.github/workflows/ci.yml` |
| GitHub | See README |
