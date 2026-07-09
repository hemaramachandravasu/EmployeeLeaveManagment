/*
    SQL Server Agent Job: nightly ETL for EmployeeLeaveDW
    Run in msdb context. Requires SQL Server Agent and appropriate permissions.
*/
USE msdb;
GO

DECLARE @JobId UNIQUEIDENTIFIER;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'ELM_Nightly_DW_ETL')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = N'ELM_Nightly_DW_ETL', @delete_unused_schedule = 1;
END
GO

EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Nightly_DW_ETL',
    @enabled = 1,
    @description = N'Nightly ETL from EmployeeLeaveDb to EmployeeLeaveDW star schema',
    @category_name = N'Data Collector',
    @owner_login_name = N'sa';
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Nightly_DW_ETL',
    @step_name = N'Run Nightly ETL',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDW',
    @command = N'EXEC dbo.sp_ETL_RunNightly;',
    @retry_attempts = 2,
    @retry_interval = 15,
    @on_success_action = 1,
    @on_fail_action = 2;
GO

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_DW_Nightly_0100',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 1,
    @active_start_time = 010000;
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Nightly_DW_ETL',
    @schedule_name = N'ELM_DW_Nightly_0100';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'ELM_Nightly_DW_ETL';
GO

PRINT 'SQL Server Agent job ELM_Nightly_DW_ETL created (daily at 01:00).';
GO
