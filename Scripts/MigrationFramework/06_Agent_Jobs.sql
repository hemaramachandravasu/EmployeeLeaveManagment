/*
================================================================================
  SQL Server Agent Jobs — Migration Framework Validation & Metadata
================================================================================
*/
USE msdb;
GO

DECLARE @Jobs TABLE (JobName SYSNAME);
INSERT INTO @Jobs (JobName) VALUES
    (N'ELM_Mig_Validation_Checks'),
    (N'ELM_Mig_Metadata_Refresh'),
    (N'ELM_Mig_Validation_Archive');

DECLARE @JobName SYSNAME;
DECLARE job_cur CURSOR LOCAL FAST_FORWARD FOR SELECT JobName FROM @Jobs;
OPEN job_cur;
FETCH NEXT FROM job_cur INTO @JobName;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @JobName)
        EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1;
    FETCH NEXT FROM job_cur INTO @JobName;
END
CLOSE job_cur;
DEALLOCATE job_cur;
GO

EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Mig_Validation_Checks',
    @enabled = 1,
    @description = N'Run data validation checks and write DataValidationLog',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Mig_Validation_Checks',
    @step_name = N'Run Validation',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Val_RunAllChecks; EXEC dbo.sp_Report_ValidationSummary @DaysBack = 7;',
    @retry_attempts = 1,
    @retry_interval = 5,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Mig_Daily_0530',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 053000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Mig_Validation_Checks',
    @schedule_name = N'ELM_Mig_Daily_0530';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Mig_Validation_Checks';
GO

EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Mig_Metadata_Refresh',
    @enabled = 1,
    @description = N'Refresh metadata lookups from LeaveTypes and core catalogs',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Mig_Metadata_Refresh',
    @step_name = N'Refresh Metadata',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Meta_RefreshCatalog;',
    @retry_attempts = 0,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Mig_Daily_0600',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 060000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Mig_Metadata_Refresh',
    @schedule_name = N'ELM_Mig_Daily_0600';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Mig_Metadata_Refresh';
GO

EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Mig_Validation_Archive',
    @enabled = 1,
    @description = N'Archive resolved validation logs',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Mig_Validation_Archive',
    @step_name = N'Archive Logs',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Val_ArchiveHistoricalLogs @RetainDays = 120;',
    @retry_attempts = 0,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Mig_Weekly_Sun_0530',
    @freq_type = 8,
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 053000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Mig_Validation_Archive',
    @schedule_name = N'ELM_Mig_Weekly_Sun_0530';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Mig_Validation_Archive';
GO

PRINT 'MigrationFramework Agent jobs created.';
GO
