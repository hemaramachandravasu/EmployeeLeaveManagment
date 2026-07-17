/*
  SQL Server Agent Jobs - Backup Automation
  Requires SQL Server Agent (not Express) and write access to BackupRootPath.
*/
USE msdb;
GO

DECLARE @Jobs TABLE (JobName SYSNAME);
INSERT INTO @Jobs VALUES
    (N'ELM_Backup_Full'),
    (N'ELM_Backup_Differential'),
    (N'ELM_Backup_Log'),
    (N'ELM_Backup_Validate'),
    (N'ELM_Ops_AccessSnapshot'),
    (N'ELM_Ops_MonitorAlerts');

DECLARE @JobName SYSNAME;
DECLARE job_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT JobName FROM @Jobs;
OPEN job_cursor;
FETCH NEXT FROM job_cursor INTO @JobName;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @JobName)
        EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1;
    FETCH NEXT FROM job_cursor INTO @JobName;
END
CLOSE job_cursor;
DEALLOCATE job_cursor;
GO

-- Full backup nightly 22:00
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Backup_Full',
    @enabled = 1,
    @description = N'Nightly full backup of EmployeeLeaveDb with VERIFYONLY',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Backup_Full',
    @step_name = N'Full Backup',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Backup_Full @DatabaseName = N''EmployeeLeaveDb'';',
    @retry_attempts = 1,
    @retry_interval = 10,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Daily_2200',
    @freq_type = 4, @freq_interval = 1, @freq_subday_type = 1,
    @active_start_time = 220000;
GO
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobschedules js INNER JOIN msdb.dbo.sysjobs j ON j.job_id = js.job_id WHERE j.name = N'ELM_Backup_Full')
    EXEC msdb.dbo.sp_attach_schedule @job_name = N'ELM_Backup_Full', @schedule_name = N'ELM_Daily_2200';
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Backup_Full';
GO

-- Differential every 6 hours (except overlapping full window handled by operator)
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Backup_Differential',
    @enabled = 1,
    @description = N'Differential backup every 6 hours',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Backup_Differential',
    @step_name = N'Differential Backup',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Backup_Differential @DatabaseName = N''EmployeeLeaveDb'';',
    @on_success_action = 1, @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Every_6Hours',
    @freq_type = 4, @freq_interval = 1, @freq_subday_type = 8, @freq_subday_interval = 6,
    @active_start_time = 010000;
GO
EXEC msdb.dbo.sp_attach_schedule @job_name = N'ELM_Backup_Differential', @schedule_name = N'ELM_Every_6Hours';
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Backup_Differential';
GO

-- Transaction log every 15 minutes
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Backup_Log',
    @enabled = 1,
    @description = N'Transaction log backup every 15 minutes (FULL recovery)',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Backup_Log',
    @step_name = N'Log Backup',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Backup_Log @DatabaseName = N''EmployeeLeaveDb'';',
    @on_success_action = 1, @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Every_15Min',
    @freq_type = 4, @freq_interval = 1, @freq_subday_type = 4, @freq_subday_interval = 15,
    @active_start_time = 000000;
GO
EXEC msdb.dbo.sp_attach_schedule @job_name = N'ELM_Backup_Log', @schedule_name = N'ELM_Every_15Min';
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Backup_Log';
GO

-- Daily backup validation 23:00
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Backup_Validate',
    @enabled = 1,
    @description = N'Validate latest backup with RESTORE VERIFYONLY',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Backup_Validate',
    @step_name = N'Verify Last Backup',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_DR_ValidateLastBackup;',
    @on_success_action = 1, @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Daily_2300',
    @freq_type = 4, @freq_interval = 1, @freq_subday_type = 1,
    @active_start_time = 230000;
GO
EXEC msdb.dbo.sp_attach_schedule @job_name = N'ELM_Backup_Validate', @schedule_name = N'ELM_Daily_2300';
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Backup_Validate';
GO

-- Access snapshot hourly
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Ops_AccessSnapshot',
    @enabled = 1,
    @description = N'Capture user session access snapshot for security audit reports',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Ops_AccessSnapshot',
    @step_name = N'Capture Access Snapshot',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Monitor_CaptureAccessSnapshot;',
    @on_success_action = 1, @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Hourly',
    @freq_type = 4, @freq_interval = 1, @freq_subday_type = 8, @freq_subday_interval = 1,
    @active_start_time = 000500;
GO
EXEC msdb.dbo.sp_attach_schedule @job_name = N'ELM_Ops_AccessSnapshot', @schedule_name = N'ELM_Hourly';
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Ops_AccessSnapshot';
GO

-- Ops monitor every 2 hours
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Ops_MonitorAlerts',
    @enabled = 1,
    @description = N'Storage / backup lag / failed job / long-tx monitoring',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Ops_MonitorAlerts',
    @step_name = N'Collect Ops Alerts',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'
EXEC dbo.sp_Monitor_BackupStatus;
EXEC dbo.sp_Monitor_FailedAgentJobs @HoursBack = 6;
EXEC dbo.sp_Monitor_StorageCapacityAlerts;
EXEC dbo.sp_Monitor_LongRunningTransactions @MinDurationSeconds = 120;
',
    @on_success_action = 1, @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Every_2Hours',
    @freq_type = 4, @freq_interval = 1, @freq_subday_type = 8, @freq_subday_interval = 2,
    @active_start_time = 001500;
GO
EXEC msdb.dbo.sp_attach_schedule @job_name = N'ELM_Ops_MonitorAlerts', @schedule_name = N'ELM_Every_2Hours';
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Ops_MonitorAlerts';
GO

PRINT 'Backup & ops Agent jobs created.';
GO
