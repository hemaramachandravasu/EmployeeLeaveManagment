/*
  Optimization master deploy — run from Scripts\Optimization folder:
    cd Scripts\Optimization
    sqlcmd -S localhost -E -C -i OPTIMIZATION_MASTER_DEPLOY.sql
  Then optionally (requires SQL Agent):
    sqlcmd -S localhost -E -C -i 07_Agent_Jobs.sql

  Prerequisites:
    • MASTER_DEPLOY.sql already applied (EmployeeLeaveDb + LeaveRequests + AuditLogs)
*/
:r 01_Filegroups_PartitionFunction.sql
GO
:r 02_Partition_LeaveRequests.sql
GO
:r 03_Partition_AuditLogs.sql
GO
:r 04_Index_Optimization.sql
GO
:r 05_Query_Optimization.sql
GO
:r 06_Ops_Analytics_Procedures.sql
GO

PRINT 'Optimization core deployed (partitioning + indexes + ops analytics). Schedule 07_Agent_Jobs.sql next.';
GO
