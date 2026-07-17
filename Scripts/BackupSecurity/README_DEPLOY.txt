/*
  Flat master deploy (no :r) — run each section via sqlcmd -i individually,
  or execute this file after deploying 01-05 and 07 separately.

  Recommended deploy sequence:
    sqlcmd -S localhost -E -C -i 01_Backup_Config_Schema.sql
    sqlcmd -S localhost -E -C -i 02_Backup_Procedures.sql
    sqlcmd -S localhost -E -C -i 03_Recovery_Procedures.sql
    sqlcmd -S localhost -E -C -i 04_Ops_Monitoring_Procedures.sql
    sqlcmd -S localhost -E -C -i 05_Report_Procedures.sql
    sqlcmd -S localhost -E -C -i 07_Security_Ops_Procedures.sql
    sqlcmd -S localhost -E -C -i 06_Agent_Jobs.sql
*/
PRINT 'See Scripts/BackupSecurity/*.sql for individual deploy scripts.';
GO
