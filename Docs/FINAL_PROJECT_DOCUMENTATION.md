# Employee Leave Management System — Final Project Documentation

**Capstone:** Final Integration, Reporting API Exposure & Documentation Module

---

## 1. Executive Summary

This solution exposes reporting and analytics capabilities built in Tasks 2–3 as secured REST endpoints for an Admin Dashboard, consolidates all SQL artifacts into `MASTER_DEPLOY.sql`, and documents the complete reporting pipeline end-to-end.

---

## 2. Architecture

| Layer | Technology | Responsibility |
|-------|------------|----------------|
| API | ASP.NET Core 10 Controllers | HTTP, validation, JWT authorization |
| Service | C# service classes | Business orchestration |
| DAL | ADO.NET repositories | SQL execution via stored procedures |
| Database | SQL Server | Schema, SPs, triggers, audit, analytics |

Background `ReportSchedulerService` writes scheduled CSV reports to `C:\Reports` (configurable).

---

## 3. Reporting API Exposure (Task 5.1)

Thin controllers delegate to `IReportService` → `IReportRepository` (ADO.NET).

| Report | Endpoint | Method(s) | Stored procedure |
|--------|----------|-----------|------------------|
| Employee Leave Summary | `/api/Report/employee-summary` | GET, POST | `sp_EmployeeLeaveSummary` |
| Monthly Leave Utilization | `/api/Report/monthly-utilization` | GET, POST | `sp_MonthlyLeaveUtilization` |
| Department-wise Statistics | `/api/Report/department-statistics` | GET, POST | `sp_DepartmentWiseLeaveStatistics` |
| Pending Leave Requests | `/api/Report/pending` | GET | `sp_PendingLeaveRequests` |

**Export endpoints (POST):**
- Excel/CSV for employee summary and department statistics via ClosedXML and CSV builders in `ReportRepository`.

**Filter DTO:** `ReportFilterDto` — `FromDate`, `ToDate`, `DepartmentId`, `EmployeeId`, `Year`, `Month`

**Validation:** `ReportFilterValidator` enforces date range, year/month bounds, and positive IDs.

---

## 4. Dashboard Data Feed Endpoints (Task 5.2)

| Endpoint | Data returned |
|----------|---------------|
| `GET /api/Dashboard` | `DashboardDto` — 7 KPI counters via `sp_GetDashboardData` |
| `GET /api/Dashboard/department-leaves?year=` | Per-department leave counts/days via `sp_DepartmentComparison` |
| `GET /api/Dashboard/monthly-trend?year=` | Monthly trend series via `sp_LeaveTrendAnalysis` |
| `GET /api/Dashboard/pending-summary` | Pending/approved/rejected snapshot |

Designed for chart widgets: bar charts (departments), line charts (monthly trend), KPI cards (summary).

---

## 5. Analytics Endpoints (Tasks 2–3)

| Endpoint | Stored procedure |
|----------|------------------|
| `GET /api/Analytics/leave-trend?year=` | `sp_LeaveTrendAnalysis` |
| `GET /api/Analytics/department-comparison?year=` | `sp_DepartmentComparison` |
| `GET /api/Analytics/frequent-leave-pattern` | `sp_FrequentLeavePattern` |
| `GET /api/Analytics/forecast-leave-utilization` | `sp_ForecastLeaveUtilization` |

Legacy analytics SP names (`sp_GetLeaveTrend`, etc.) are also deployed for backward compatibility.

---

## 6. Final Database Package (Task 5.3)

**Single script:** `MASTER_DEPLOY.sql`

Deployment order inside the script:
1. Create database `EmployeeLeaveDb`
2. Drop legacy objects (tables, triggers)
3. Create tables: Departments, Roles, LeaveTypes, Employees, Users, LeaveRequests, AuditLogs, LeaveRequestsArchive
4. Indexes
5. Audit triggers on Employees and LeaveRequests
6. Employee, leave, dashboard, report, analytics, and audit stored procedures (34 total)
7. Seed data: roles, admin user, departments, leave types, employees, sample leave requests

**Run:**
```powershell
sqlcmd -S <server> -E -C -i MASTER_DEPLOY.sql
```

`DATABASE_SETUP.sql` and `Scripts/Database/DB_Deploy_NoSession.sql` are deprecated in favor of `MASTER_DEPLOY.sql`.

---

## 7. Security & Validation (Task 5.4)

### JWT Authentication
- `POST /api/Auth/login` — issues JWT (public)
- Config: `appsettings.json` → `Jwt:Key`, `Issuer`, `Audience`, `ExpiresMinutes`
- Users stored in `dbo.Users` with PBKDF2 password hashes
- Default admin: **admin / Admin@123**

### Authorization
- `[Authorize(Roles = "Admin")]` on `ReportController`, `DashboardController`, `AnalyticsController`
- Swagger configured with Bearer token security scheme

### Validation
- `ReportFilterValidator` for report filters
- Year bounds (2000–2100) on dashboard/analytics query params
- Model validation on `LoginDto` via data annotations

---

## 8. Audit Trail (Tasks 2–3)

- Table: `dbo.AuditLogs` (RecordId, ActionType, OldValue, NewValue JSON snapshots)
- Triggers: `trg_Employees_Audit`, `trg_LeaveRequests_Audit`
- SPs: `sp_GetAuditHistory`, `sp_GetAuditLogById`, `sp_GetAuditLogsByTable`, `sp_GetAuditLogsByUser`, `sp_GetAuditByDate`
- See `Docs/Reporting-Audit-Design.md` for design rationale

---

## 9. Scheduled Reporting

`ReportSchedulerService` (hosted background service):
- Interval: `Reporting:IntervalHours` (default 24)
- Output: `Reporting:OutputFolder` (default `C:\Reports`)
- Generates `_DepartmentStats.csv` and `_MonthlyUtilization.csv`

---

## 10. Testing (Task 5.6)

**Test project:** `EmployeeLeaveManagment.Tests`

| Test class | Coverage |
|------------|----------|
| `AnalyticsRepositoryTests` | Leave trend analytics service |
| `ReportFilterValidatorTests` | Filter validation rules |
| `ReportServiceTests` | Report queries and CSV export |
| `AuthAndDashboardTests` | Password hashing, dashboard feeds |

Run: `dotnet test`

---

## 11. Demo Walkthrough

1. Deploy DB: `sqlcmd -S localhost -E -C -i MASTER_DEPLOY.sql`
2. Start API: `dotnet run` in `EmployeeLeaveManagment`
3. Open Swagger: http://localhost:5300/swagger
4. Login: `POST /api/Auth/login` with `admin` / `Admin@123`
5. Authorize Swagger with `Bearer <token>`
6. Call `GET /api/Dashboard` — verify KPI counts
7. Call `GET /api/Report/pending` — verify pending leave rows
8. Call `GET /api/Report/employee-summary` — verify summary data
9. Call `POST /api/Report/export/employee-csv` — download CSV
10. Call `GET /api/Analytics/leave-trend?year=2026` — verify trend data

Import `Docs/EmployeeLeaveManagement.postman_collection.json` into Postman for a pre-built collection.

---

## 12. File Index

| Path | Purpose |
|------|---------|
| `MASTER_DEPLOY.sql` | Complete database deployment |
| `README.md` | Quick start guide |
| `EmployeeLeaveManagment/Controllers/` | REST API controllers |
| `EmployeeLeaveManagment/Services/` | Service layer |
| `EmployeeLeaveManagment/Data/` | ADO.NET repositories |
| `EmployeeLeaveManagment/Security/` | JWT + password hashing |
| `Docs/Reporting-Audit-Design.md` | Audit/analytics design |
| `Docs/EmployeeLeaveManagement.postman_collection.json` | Postman collection |

---

## 13. Assumptions & Limitations

- Admin dashboard UI is a separate consumer of these JSON feeds
- JWT secret should be rotated and stored securely in production (User Secrets / Key Vault)
- Re-running `MASTER_DEPLOY.sql` resets application data
- Employee/Leave/Department CRUD endpoints remain open; secure as needed for production
