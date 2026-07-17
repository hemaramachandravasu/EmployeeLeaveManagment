/*
  BackupSecurity master deploy — run from Scripts\BackupSecurity folder:
    cd Scripts\BackupSecurity
    sqlcmd -S localhost -E -C -i BACKUP_SECURITY_MASTER_DEPLOY.sql
  Then optionally:
    sqlcmd -S localhost -E -C -i 06_Agent_Jobs.sql
*/
:r 01_Backup_Config_Schema.sql
GO
:r 02_Backup_Procedures.sql
GO
:r 03_Recovery_Procedures.sql
GO
:r 04_Ops_Monitoring_Procedures.sql
GO
:r 05_Report_Procedures.sql
GO
:r 07_Security_Ops_Procedures.sql
GO

PRINT 'BackupSecurity core deployed. Create C:\Backup\EmployeeLeaveDb then schedule 06_Agent_Jobs.sql.';
GO
