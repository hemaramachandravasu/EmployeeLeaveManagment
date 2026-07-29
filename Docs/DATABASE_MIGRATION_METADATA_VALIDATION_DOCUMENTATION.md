# Database Migration Framework, Data Validation & Metadata Management

## 1. Overview

This module adds **controlled schema migrations**, **application metadata catalogs**, and a **data validation framework** for `EmployeeLeaveDb`.

| Capability | Purpose |
|------------|---------|
| Migration framework | Versioned apply/rollback with `SchemaMigrationHistory` |
| Metadata management | Modules, config categories, lookups, audit categories |
| Data validation | Balances, mandatory records, duplicates, references, orphans |
| Reporting | Migration history, validation summary, metadata usage, DQ dashboard |
| Automation | Agent jobs for validation, metadata refresh, log archive |

**Deploy:** `Scripts/MigrationFramework/`  
**API:** `/api/MigrationFramework` (Admin JWT)  
**GitHub:** https://github.com/hemaramachandravasu/EmployeeLeaveManagment

---

## 2. Migration Strategy

1. Record every change with a unique `VersionNumber` (e.g. `0001.0001`).  
2. Provide **UpSql** (apply) and **DownSql** (rollback) text.  
3. `sp_Mig_Apply` runs UpSql in a transaction and marks status `Applied`.  
4. `sp_Mig_Rollback` runs DownSql for a version (or latest non-baseline) and marks `RolledBack`.  
5. Baseline `0001.0000` marks framework install and cannot be rolled back.

Sample demo migration: `sp_Mig_ApplySample_0001_0001` creates `Meta_SystemSetting`.

---

## 3. Metadata Design

| Table | Contents |
|-------|----------|
| `Meta_ApplicationModule` | AUTH, LEAVE, REPORT, … |
| `Meta_ConfigCategory` | LEAVE_POLICY, ALERT_THRESHOLDS, BACKUP, … |
| `Meta_LookupValue` | LEAVE_STATUS, GENDER, SEVERITY, LEAVE_TYPE |
| `Meta_AuditCategory` | DML_CHANGE, USER_ACTIVITY, MIGRATION, … |

`sp_Meta_RefreshCatalog` ensures core lookups and syncs LeaveTypes into `LEAVE_TYPE`.

---

## 4. Validation Rules

| CheckCode | Detects |
|-----------|---------|
| `INVALID_BALANCE` / `BALANCE_MISMATCH` | Bad or drifted leave balances |
| `MISSING_MANDATORY` | Admin role/user, leave types, departments, status lookups |
| `DUPLICATE_MASTER` | Duplicate departments, leave types, roles, employees, users |
| `INVALID_REFERENCE` | Leave status / config module codes not in metadata |
| `ORPHAN_RECORD` | Broken FKs on leave, users, employees |

Orchestrator: `sp_Val_RunAllChecks`.

---

## 5. Automation Workflow

| Job | Schedule |
|-----|----------|
| `ELM_Mig_Validation_Checks` | Daily 05:30 |
| `ELM_Mig_Metadata_Refresh` | Daily 06:00 |
| `ELM_Mig_Validation_Archive` | Weekly Sun 05:30 |

---

## 6. Deploy

```powershell
cd C:\Users\harim\Downloads\EmployeeLeaveManagment\Scripts\MigrationFramework
sqlcmd -S localhost -E -C -I -i MIGRATION_FRAMEWORK_MASTER_DEPLOY.sql
sqlcmd -S localhost -E -C -i 06_Agent_Jobs.sql   # optional
```

Verify:

```sql
EXEC dbo.sp_Meta_RefreshCatalog;
EXEC dbo.sp_Val_RunAllChecks;
EXEC dbo.sp_Report_DataQualityDashboard;
EXEC dbo.sp_Mig_ApplySample_0001_0001;  -- once
```

---

## 7. Future Enhancements

1. File-based migration pack runner (scan `Migrations/*.sql` from disk).  
2. Pre-deploy checksum / dependency graph between versions.  
3. Soft-block leave apply when open `Critical` validation issues exist.  
4. UI for reviewing pending migrations before apply.  
5. Integrate with CI to fail builds when validation Critical count &gt; 0.

---

## 8. Deliverable Map

| Item | Path |
|------|------|
| Scripts | `Scripts/MigrationFramework/*.sql` |
| API | `Controllers/MigrationFrameworkController.cs` |
| Docs | `Docs/DATABASE_MIGRATION_METADATA_VALIDATION_DOCUMENTATION.md` |
| Samples | `Docs/Samples/MigrationFramework/` |
