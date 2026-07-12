/*
================================================================================
  MAINTENANCE_MASTER_DEPLOY.sql
  Deploys archival, monitoring, maintenance, and report procedures.
  Prerequisite: EmployeeLeaveDb from MASTER_DEPLOY.sql

  Usage:
    cd Scripts\Maintenance
    sqlcmd -S localhost -E -C -i MAINTENANCE_MASTER_DEPLOY.sql
================================================================================
*/
:r 01_Archive_Schema.sql
GO
:r 02_Archive_Procedures.sql
GO
:r 03_Monitoring_Procedures.sql
GO
:r 04_Maintenance_Procedures.sql
GO
:r 05_Report_Procedures.sql
GO

USE EmployeeLeaveDb;
GO

EXEC dbo.sp_Monitor_CaptureMetricSnapshot;
GO

PRINT '============================================================';
PRINT ' Maintenance module deployed successfully.';
PRINT ' Optional: run 06_Agent_Jobs.sql to schedule Agent jobs.';
PRINT '============================================================';
GO
