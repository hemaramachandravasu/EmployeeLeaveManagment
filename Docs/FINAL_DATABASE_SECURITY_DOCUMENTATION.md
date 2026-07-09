# Employee Leave Management — Final Database Security Documentation

**Module:** Advanced Database Security, Data Masking & System Integration  
**Database:** `EmployeeLeaveDb` on SQL Server

---

## 1. Deployment Order

| Step | Script | Purpose |
|------|--------|---------|
| 1 | `MASTER_DEPLOY.sql` | Schema, stored procedures, seed data |
| 2 | `Scripts/Security/SECURITY_DEPLOY.sql` | DDM, RLS, roles, logins, health monitoring |

```powershell
sqlcmd -S localhost -E -C -i MASTER_DEPLOY.sql
sqlcmd -S localhost -E -C -d EmployeeLeaveDb -i Scripts\Security\SECURITY_DEPLOY.sql
```

---

## 2. Dynamic Data Masking (DDM)

Masking is applied at the **database layer**. Non-privileged principals see obfuscated values; principals with `UNMASK` (role `db_elm_Admin`) see clear text.

| Table | Column | Mask function | Rationale |
|-------|--------|---------------|-----------|
| `Employees` | `Email` | `email()` | Contact PII |
| `Employees` | `MobileNumber` | `partial(1,"XXX-XXX-",4)` | Phone number |
| `Employees` | `DateOfBirth` | `default()` | Personal identifier |
| `Employees` | `Salary` | `default()` | Compensation sensitivity |
| `Employees` | `Address` | `partial(2,"XXXX",2)` | Location PII |
| `Employees` | `EmployeeCode` | `partial(2,"XX",2)` | Workforce identifier |
| `Users` | `PasswordHash` | `default()` | Credential material |
| `Users` | `Email` | `email()` | Account contact |

**Application impact:** The Web API connects with a privileged Windows/SQL principal for normal operation. Direct access via `elm_ReportViewer` demonstrates masking without changing ADO.NET code. Reporting APIs inherit masking only when executed under a principal **without** `UNMASK`.

---

## 3. Row-Level Security (RLS)

### Session context keys (set by `SqlConnectionFactory` per HTTP request)

| Key | Source | Example |
|-----|--------|---------|
| `RoleName` | JWT `ClaimTypes.Role` | `Admin`, `Manager`, `Employee` |
| `EmployeeId` | JWT `EmployeeId` claim | `2` |
| `DepartmentId` | JWT `DepartmentId` claim | `2` |

### Policies

| Policy | Table | Rule |
|--------|-------|------|
| `security.LeaveRequests_RLS` | `LeaveRequests` | **Admin:** all rows · **Employee:** own `EmployeeId` · **Manager:** rows for employees in manager's `DepartmentId` |
| `security.Employees_RLS` | `Employees` | **Admin:** all rows · **Employee:** own row · **Manager:** rows in same department |

Background `ReportSchedulerService` runs without HTTP context → defaults to `Admin` session context.

### Seed users for testing

| Username | Password | Role | EmployeeId | Department |
|----------|----------|------|------------|------------|
| `admin` | `Admin@123` | Admin | 1 | 2 (Engineering) |
| `manager` | `Admin@123` | Manager | 1 (Alice) | 2 |
| `employee` | `Admin@123` | Employee | 2 (Bob) | 2 |

---

## 4. Database Roles & Least Privilege

| Role | Purpose | Key grants |
|------|---------|------------|
| `db_elm_ReadOnly` | Reference lookups | `SELECT` on `Departments`, `LeaveTypes`; `EXEC sp_GetDashboardData` |
| `db_elm_ReportViewer` | Reporting analysts | `EXEC` on report/analytics SPs; **no UNMASK** |
| `db_elm_DataEntry` | Transactional operations | `EXEC` on leave/employee mutation SPs |
| `db_elm_Admin` | Full administration | `EXEC` on schema, `UNMASK`, DML on `dbo` |

### SQL logins (development)

| Login | Password | Database role |
|-------|----------|---------------|
| `elm_ReportViewer` | `Elm_ReportViewer_Dev1!` | `db_elm_ReportViewer` |
| `elm_DataEntry` | `Elm_DataEntry_Dev1!` | `db_elm_DataEntry` |
| `elm_Admin` | `Elm_Admin_Dev1!` | `db_elm_Admin` |

`PUBLIC` `SELECT` on sensitive tables was revoked to enforce least privilege.

---

## 5. Integration Test Results

Run locally (requires deployed DB + `SECURITY_DEPLOY.sql`):

```powershell
dotnet test --filter "Category=Integration"
```

| Test | Scenario | Expected result |
|------|----------|-----------------|
| `RLS_Employee_SeesOnlyOwnLeaveRequests` | Employee context (`EmployeeId=2`) | `COUNT(*)` from `LeaveRequests` = **1** |
| `RLS_Manager_SeesDepartmentLeaveRequests` | Manager context (`DepartmentId=2`) | Count **≥ 2** (department team) |
| `RLS_Admin_SeesAllLeaveRequests` | Admin context | Count **≥ 3** (all seed rows) |
| `DDM_ReportViewerLogin_SeesMaskedEmployeeEmail` | Login `elm_ReportViewer` | Email contains `XXXX` mask pattern |
| `HealthCheck_ReturnsSecuritySummary` | `sp_DatabaseHealthCheck` | Masked columns ≥ 5, security policies ≥ 2 |

**API reporting note:** When the API runs as `dbo`/Windows admin, report endpoints return unmasked data by design. Masking is enforced for `elm_ReportViewer` and other non-UNMASK principals.

---

## 6. Database Health Monitoring

**Procedure:** `dbo.sp_DatabaseHealthCheck`

Returns four result sets:
1. Table row counts and space usage (MB)
2. Top 25 fragmented indexes (page count > 100)
3. Top 20 long-running requests (DMVs)
4. Security posture summary (masked columns, RLS policies, ELM roles)

```sql
EXEC dbo.sp_DatabaseHealthCheck;
```

Run on demand during maintenance windows or after large data loads.

---

## 7. Monitoring Approach

| Technique | Use |
|-----------|-----|
| `sp_DatabaseHealthCheck` | Scheduled on-demand health review |
| SQL Server Extended Events | Capture `blocked_process_report`, `long_running_queries` in production |
| SQL Server Profiler (dev) | Validate ADO.NET issues SESSION_CONTEXT before SP execution |

---

## 8. Known Limitations & Recommendations

| Limitation | Recommendation |
|------------|----------------|
| Single app connection string in dev | Use separate SQL logins per environment in production |
| DDM bypass for dbo/app admin | Use `elm_ReportViewer` for analyst access; grant `UNMASK` only to `db_elm_Admin` |
| RLS depends on SESSION_CONTEXT | Ensure all new repositories use `ISqlConnectionFactory` |
| Dev passwords in SQL script | Rotate and store in Azure Key Vault / GitHub Secrets |
| No column encryption (Always Encrypted) | Evaluate for highest-sensitivity fields in future phase |

---

## 9. Related Files

- `Scripts/Security/SECURITY_DEPLOY.sql` — security deployment
- `EmployeeLeaveManagment/Data/SqlConnectionFactory.cs` — SESSION_CONTEXT bridge
- `EmployeeLeaveManagment.Tests/SecurityIntegrationTests.cs` — integration tests
- `.github/workflows/ci.yml` — CI pipeline (unit tests)
- `Docs/FINAL_PROJECT_DOCUMENTATION.md` — Task 5 API documentation
