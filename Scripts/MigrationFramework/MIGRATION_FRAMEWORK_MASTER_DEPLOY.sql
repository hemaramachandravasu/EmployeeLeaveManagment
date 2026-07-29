/*
  MigrationFramework master deploy — from Scripts\MigrationFramework:
    cd C:\Users\harim\Downloads\EmployeeLeaveManagment\Scripts\MigrationFramework
    sqlcmd -S localhost -E -C -I -i MIGRATION_FRAMEWORK_MASTER_DEPLOY.sql
  Optional:
    sqlcmd -S localhost -E -C -i 06_Agent_Jobs.sql
*/
:r 01_Migration_Metadata_Schema.sql
GO
:r 02_Migration_Procedures.sql
GO
:r 03_Metadata_Procedures.sql
GO
:r 04_Validation_Procedures.sql
GO
:r 05_Report_Procedures.sql
GO

PRINT 'MigrationFramework core deployed. Schedule 06_Agent_Jobs.sql next.';
GO
