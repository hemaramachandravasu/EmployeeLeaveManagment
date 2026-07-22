# Employee Leave Management System

ASP.NET Core Web API for employee leave management with **reporting**, **analytics**, **dashboard feeds**, JWT authentication, and a consolidated SQL Server deployment package.

## Quick Start

### 1. Deploy database
```powershell
sqlcmd -S localhost -E -C -i MASTER_DEPLOY.sql
```

### 2. Run API
```powershell
cd EmployeeLeaveManagment
dotnet run
```

### 3. Open Swagger
http://localhost:5300/swagger

### 4. Login (JWT)
```http
POST /api/Auth/login
{
  "userName": "admin",
  "password": "Admin@123"
}
```

Copy the `token` from the response. In Swagger, click **Authorize** and enter: `Bearer <your-token>`

## Architecture

```
Controller → Service → Repository (ADO.NET) → SQL Server stored procedures
```

## Key API Areas

| Area | Base route | Auth |
|------|------------|------|
| Auth | `/api/Auth` | Public login |
| Reports | `/api/Report` | Admin JWT |
| Dashboard | `/api/Dashboard` | Admin JWT |
| Analytics | `/api/Analytics` | Admin JWT |
| Data Warehouse | `/api/DataWarehouse` | Admin JWT |
| Maintenance | `/api/Maintenance` | Admin JWT |
| Backup & Security Ops | `/api/BackupSecurity` | Admin JWT |
| Optimization & Partitioning | `/api/Optimization` | Admin JWT |
| Audit Integrity & Compliance | `/api/AuditIntegrity` | Admin JWT |
| Employees | `/api/Employee` | Open |
| Leaves | `/api/Leave` | Open |
| Departments | `/api/Department` | Open |

## Reporting Endpoints (Task 5)

| Report | GET | POST |
|--------|-----|------|
| Employee Leave Summary | `/api/Report/employee-summary` | same path |
| Monthly Utilization | `/api/Report/monthly-utilization` | same path |
| Department Statistics | `/api/Report/department-statistics` | same path |
| Pending Requests | `/api/Report/pending` | — |

Exports (POST, Admin JWT):
- `/api/Report/export/employee-excel`
- `/api/Report/export/department-excel`
- `/api/Report/export/employee-csv`
- `/api/Report/export/department-csv`

## Dashboard Feeds

| Endpoint | Purpose |
|----------|---------|
| `GET /api/Dashboard` | KPI summary counts |
| `GET /api/Dashboard/department-leaves?year=2026` | Department chart data |
| `GET /api/Dashboard/monthly-trend?year=2026` | Monthly trend chart data |
| `GET /api/Dashboard/pending-summary` | Pending/approved/rejected snapshot |

## Database

| Script | Purpose |
|--------|---------|
| `MASTER_DEPLOY.sql` | Schema, stored procedures, seed data |
| `Scripts/Security/SECURITY_DEPLOY.sql` | DDM, RLS, roles, health monitoring |
| `Scripts/Maintenance/MAINTENANCE_MASTER_DEPLOY.sql` | Archival, monitoring, maintenance jobs |
| `Scripts/DataWarehouse/DW_MASTER_DEPLOY.sql` | Analytics warehouse + ETL |
| `Scripts/BackupSecurity/BACKUP_SECURITY_MASTER_DEPLOY.sql` | Backup automation, DR, ops monitoring |
| `Scripts/Optimization/OPTIMIZATION_MASTER_DEPLOY.sql` | Partitioning, index optimization, ops analytics |
| `Scripts/AuditIntegrity/AUDIT_INTEGRITY_MASTER_DEPLOY.sql` | Auditing, integrity checks, compliance reports |

```powershell
sqlcmd -S localhost -E -C -i MASTER_DEPLOY.sql
sqlcmd -S localhost -E -C -i Scripts\Security\SECURITY_DEPLOY.sql
sqlcmd -S localhost -E -C -i Scripts\Maintenance\MAINTENANCE_MASTER_DEPLOY.sql
New-Item -ItemType Directory -Force -Path C:\Backup\EmployeeLeaveDb | Out-Null
cd Scripts\BackupSecurity
sqlcmd -S localhost -E -C -i BACKUP_SECURITY_MASTER_DEPLOY.sql
cd ..\Optimization
sqlcmd -S localhost -E -C -i OPTIMIZATION_MASTER_DEPLOY.sql
sqlcmd -S localhost -E -C -i 07_Agent_Jobs.sql
cd ..\AuditIntegrity
sqlcmd -S localhost -E -C -i AUDIT_INTEGRITY_MASTER_DEPLOY.sql
sqlcmd -S localhost -E -C -i 06_Agent_Jobs.sql
```

Default admin: `admin` / `Admin@123`  
Security details: [FINAL_DATABASE_SECURITY_DOCUMENTATION.md](Docs/FINAL_DATABASE_SECURITY_DOCUMENTATION.md)  
Maintenance module: [DATABASE_MAINTENANCE_DOCUMENTATION.md](Docs/DATABASE_MAINTENANCE_DOCUMENTATION.md)  
Data warehouse: [DATA_WAREHOUSE_DOCUMENTATION.md](Docs/DATA_WAREHOUSE_DOCUMENTATION.md)  
Backup / DR / Security ops: [BACKUP_SECURITY_DISASTER_RECOVERY_DOCUMENTATION.md](Docs/BACKUP_SECURITY_DISASTER_RECOVERY_DOCUMENTATION.md)  
Optimization / partitioning: [DATABASE_OPTIMIZATION_PARTITIONING_DOCUMENTATION.md](Docs/DATABASE_OPTIMIZATION_PARTITIONING_DOCUMENTATION.md)  
Audit / integrity / compliance: [DATABASE_AUDITING_INTEGRITY_COMPLIANCE_DOCUMENTATION.md](Docs/DATABASE_AUDITING_INTEGRITY_COMPLIANCE_DOCUMENTATION.md)

## Tests

```powershell
dotnet test
```

## Documentation

- [Final Project Documentation](Docs/FINAL_PROJECT_DOCUMENTATION.md)
- [Database Maintenance Documentation](Docs/DATABASE_MAINTENANCE_DOCUMENTATION.md)
- [Data Warehouse Documentation](Docs/DATA_WAREHOUSE_DOCUMENTATION.md)
- [Backup, Security & Disaster Recovery](Docs/BACKUP_SECURITY_DISASTER_RECOVERY_DOCUMENTATION.md)
- [Database Optimization, Partitioning & Operational Analytics](Docs/DATABASE_OPTIMIZATION_PARTITIONING_DOCUMENTATION.md)
- [Database Auditing, Integrity & Compliance](Docs/DATABASE_AUDITING_INTEGRITY_COMPLIANCE_DOCUMENTATION.md)
- [Reporting & Audit Design](Docs/Reporting-Audit-Design.md)
- [Postman Collection](Docs/EmployeeLeaveManagement.postman_collection.json)
- GitHub: https://github.com/hemaramachandravasu/EmployeeLeaveManagment

## Tech Stack

- ASP.NET Core 10 Web API
- ADO.NET + SQL Server
- JWT Bearer authentication
- Swagger / OpenAPI
- ClosedXML (Excel export)
- xUnit tests
