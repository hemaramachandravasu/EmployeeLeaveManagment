# Database Security, Backup Automation & Disaster Recovery — Technical Documentation

## 1. Overview

This module adds **backup automation**, **disaster recovery** tooling, **operational monitoring**, and **security operations reporting** for `EmployeeLeaveDb`, complementing the existing DDM/RLS package in `Scripts/Security/SECURITY_DEPLOY.sql`.

| Capability | Purpose |
|------------|---------|
| Full / Diff / Log backups | Automated backup chain with CHECKSUM + optional VERIFYONLY |
| Backup history | Custom `BackupRunLog` plus msdb cross-check |
| Point-in-time recovery | Script generator (review-then-run) |
| Ops monitoring | Backup lag, failed Agent jobs, storage alerts, long transactions |
| Security reporting | Access snapshots, role membership, masked columns |
| API exports | Excel / CSV for admin dashboards |

---

## 2. Backup Strategy

### Recovery model
`EmployeeLeaveDb` is set to **FULL** recovery so transaction log backups enable PITR.

### Schedule (Agent jobs in `06_Agent_Jobs.sql`)

| Job | Schedule | Procedure |
|-----|----------|-----------|
| `ELM_Backup_Full` | Daily 22:00 | `sp_Backup_Full` |
| `ELM_Backup_Differential` | Every 6 hours | `sp_Backup_Differential` |
| `ELM_Backup_Log` | Every 15 minutes | `sp_Backup_Log` |
| `ELM_Backup_Validate` | Daily 23:00 | `sp_DR_ValidateLastBackup` |

### Paths & retention
Configured in `dbo.BackupConfig` (default root: `C:\Backup\EmployeeLeaveDb\`):

| Type | Default retention |
|------|-------------------|
| Full | 14 days |
| Differential | 7 days |
| Log | 3 days |

Create the backup folder on the SQL Server host **before** the first run:

```powershell
New-Item -ItemType Directory -Force -Path C:\Backup\EmployeeLeaveDb
```

### Verification
Each backup optionally runs `RESTORE VERIFYONLY ... WITH CHECKSUM`. Status becomes `Verified` when successful. Results are stored in `BackupRunLog` and `RecoveryValidationLog`.

---

## 3. Disaster Recovery Plan

### Day-to-day
1. Confirm last full / log health via `GET /api/BackupSecurity/backup-status`
2. Nightly validation job runs VERIFYONLY on the latest backup

### Point-in-time recovery (operator procedure)
1. Call `POST /api/BackupSecurity/dr/point-in-time-script` with `{ "pointInTimeUtc": "..." }`  
   or run `EXEC dbo.sp_DR_GeneratePointInTimeRestoreScript @PointInTimeUtc = '...'`
2. Review the generated T-SQL (Full → Diff → Log STOPAT → RECOVERY)
3. Execute on a **recovery instance** with adequate disk
4. Run `DBCC CHECKDB` on the restored database
5. Cutover / failover per organizational change-management

### Restore validation
- `sp_DR_ValidateLastBackup` — VERIFYONLY without restoring
- `sp_DR_GetBackupChain` — LSN continuity check for planning
- `sp_Report_RecoveryValidation` — historical validation outcomes

**Important:** Generated restore scripts intentionally do **not** auto-execute against production.

---

## 4. Security Architecture

| Layer | Implementation |
|-------|----------------|
| Dynamic Data Masking | `Scripts/Security/SECURITY_DEPLOY.sql` |
| Row-Level Security | Admin / Manager / Employee via `SESSION_CONTEXT` |
| DB roles | `db_elm_ReadOnly`, `db_elm_ReportViewer`, `db_elm_DataEntry`, `db_elm_Admin` |
| Dev logins | `elm_*` least-privilege logins |
| Ops helpers | `sp_Security_ListUsersAndLogins`, `sp_Security_GrantLeastPrivilegePreset` |
| Access audit | Hourly session snapshot → `DbAccessAuditLog` |

Application JWT Admin APIs expose security summary reports without granting `sysadmin` to the portal.

---

## 5. Monitoring Framework

| Procedure | Signal |
|-----------|--------|
| `sp_Monitor_BackupStatus` | Backup age health + lag alerts |
| `sp_Monitor_FailedAgentJobs` | Failed `ELM_*` job steps |
| `sp_Monitor_StorageCapacityAlerts` | 80% warn / 90% critical |
| `sp_Monitor_LongRunningTransactions` | Open transactions over threshold |
| `sp_Monitor_CaptureAccessSnapshot` | Session inventory for audit reports |

Alerts land in `OpsAlertLog` (`GET /api/BackupSecurity/alerts`).

---

## 6. API Surface (Admin JWT)

| Endpoint | Purpose |
|----------|---------|
| `GET /api/BackupSecurity/backup-status` | Full/log backup health |
| `GET /api/BackupSecurity/reports/backup-history` | Backup history |
| `GET /api/BackupSecurity/reports/recovery-validation` | Validation history |
| `GET /api/BackupSecurity/reports/security-audit` | Access / roles / masks |
| `GET /api/BackupSecurity/reports/database-health` | Health status |
| `GET /api/BackupSecurity/reports/job-execution` | Agent job history |
| `GET /api/BackupSecurity/alerts` | Ops alerts |
| `POST /api/BackupSecurity/dr/point-in-time-script` | Generate PITR script |
| `POST /api/BackupSecurity/export/*-excel\|*-csv` | Excel/CSV exports |

ADO.NET: `BackupSecurityRepository` → `BackupSecurityService` → `BackupSecurityController`

---

## 7. Deployment

```powershell
# 1. Core + security
sqlcmd -S localhost -E -C -i MASTER_DEPLOY.sql
sqlcmd -S localhost -E -C -i Scripts\Security\SECURITY_DEPLOY.sql

# 2. Backup / DR / ops
cd Scripts\BackupSecurity
New-Item -ItemType Directory -Force -Path C:\Backup\EmployeeLeaveDb
sqlcmd -S localhost -E -C -i BACKUP_SECURITY_MASTER_DEPLOY.sql
sqlcmd -S localhost -E -C -i 06_Agent_Jobs.sql

# 3. Smoke test
sqlcmd -S localhost -E -C -Q "USE EmployeeLeaveDb; EXEC dbo.sp_Backup_Full;"
```

---

## 8. Operational Recommendations

1. Store backups on a **separate volume** (or off-host) from data/log files
2. Encrypt backups at rest (BitLocker / TDE / `BACKUP ... WITH ENCRYPTION`)
3. Rotate `elm_*` SQL login passwords; never use `sa` in applications
4. Test PITR at least quarterly to a non-prod instance
5. Monitor `OpsAlertLog` critical items in the Admin portal daily
6. Keep Agent enabled — Express edition needs Task Scheduler alternatives

---

## 9. Future Improvements

- Backup to Azure Blob / network share with restore tests
- SQL Server Audit specification for DML on PII tables
- Automated email Operator alerts on Critical severity
- Always On Availability Groups for HA beyond backups
- Immutable backup retention (WORM) for ransomware resilience

---

## 10. File Inventory

| File | Description |
|------|-------------|
| `Scripts/BackupSecurity/01_Backup_Config_Schema.sql` | Config + log tables |
| `Scripts/BackupSecurity/02_Backup_Procedures.sql` | Full/Diff/Log/Verify |
| `Scripts/BackupSecurity/03_Recovery_Procedures.sql` | PITR + validation |
| `Scripts/BackupSecurity/04_Ops_Monitoring_Procedures.sql` | Monitoring |
| `Scripts/BackupSecurity/05_Report_Procedures.sql` | Report SPs |
| `Scripts/BackupSecurity/06_Agent_Jobs.sql` | Agent schedules |
| `Scripts/BackupSecurity/07_Security_Ops_Procedures.sql` | Login/role helpers |
| `Scripts/Security/SECURITY_DEPLOY.sql` | DDM / RLS / roles |
| `Docs/Samples/BackupSecurity/` | Sample Excel/CSV |
| `EmployeeLeaveManagment/Controllers/BackupSecurityController.cs` | REST API |

## 11. Repository

https://github.com/hemaramachandravasu/EmployeeLeaveManagment
