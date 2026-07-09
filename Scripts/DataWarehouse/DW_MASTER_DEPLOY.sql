/*
    Employee Leave Management - Data Warehouse Master Deployment
    Deploys: star schema, ETL procedures, analytics procedures, initial ETL run.

    Prerequisites:
      - EmployeeLeaveDb deployed via MASTER_DEPLOY.sql
      - SQL Server instance with both databases on same server

    Usage:
      sqlcmd -S localhost -E -i DW_MASTER_DEPLOY.sql
*/
:r 01_DW_Schema.sql
GO
:r 02_ETL_Procedures.sql
GO
:r 03_Analytics_Procedures.sql
GO

USE EmployeeLeaveDW;
GO

-- Initial full load
EXEC dbo.sp_ETL_RunNightly;
GO

PRINT 'EmployeeLeaveDW deployment and initial ETL load completed.';
PRINT 'Optional: run 04_Agent_Job.sql in msdb to schedule nightly ETL.';
GO
