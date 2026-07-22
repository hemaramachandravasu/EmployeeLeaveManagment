/*
  AuditIntegrity master deploy — run from Scripts\AuditIntegrity folder:
    cd Scripts\AuditIntegrity
    sqlcmd -S localhost -E -C -i AUDIT_INTEGRITY_MASTER_DEPLOY.sql
  Then optionally (requires SQL Agent):
    sqlcmd -S localhost -E -C -i 06_Agent_Jobs.sql

  Prerequisites:
    • MASTER_DEPLOY.sql already applied (EmployeeLeaveDb)
*/
:r 01_AuditIntegrity_Schema.sql
GO
:r 02_Auditing_Triggers.sql
GO
:r 03_Integrity_Validation_Procedures.sql
GO
:r 04_Compliance_Report_Procedures.sql
GO
:r 05_Monitoring_Procedures.sql
GO

PRINT 'AuditIntegrity core deployed (auditing + integrity + compliance reports + monitoring). Schedule 06_Agent_Jobs.sql next.';
GO
