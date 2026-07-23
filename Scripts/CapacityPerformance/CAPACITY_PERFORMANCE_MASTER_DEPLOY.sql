/*
  CapacityPerformance master deploy — run from Scripts\CapacityPerformance:
    cd C:\Users\harim\Downloads\EmployeeLeaveManagment\Scripts\CapacityPerformance
    sqlcmd -S localhost -E -C -I -i CAPACITY_PERFORMANCE_MASTER_DEPLOY.sql
  Then optionally:
    sqlcmd -S localhost -E -C -i 06_Agent_Jobs.sql

  Prerequisites: MASTER_DEPLOY.sql applied (EmployeeLeaveDb)
*/
:r 01_CapacityPerformance_Schema.sql
GO
:r 02_Capacity_Monitoring_Procedures.sql
GO
:r 03_SqlPerformance_Procedures.sql
GO
:r 04_Alerting_Procedures.sql
GO
:r 05_Report_Procedures.sql
GO

PRINT 'CapacityPerformance core deployed. Schedule 06_Agent_Jobs.sql next.';
GO
