/*
================================================================================
  SQL Server Agent Jobs — Database Maintenance
  Requires SQL Server Agent (not available on Express).
================================================================================
*/
USE msdb;
GO

/* Helper: drop job if exists */
DECLARE @Jobs TABLE (JobName SYSNAME);
INSERT INTO @Jobs (JobName) VALUES
    (N'ELM_Index_Maintenance'),
    (N'ELM_Statistics_Update'),
    (N'ELM_Archive_Execution'),
    (N'ELM_Temp_Cleanup'),
    (N'ELM_Integrity_Check'),
    (N'ELM_Metric_Snapshot');

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

/* ---- 1) Index Rebuild / Reorganize — Sunday 02:00 ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Index_Maintenance',
    @enabled = 1,
    @description = N'Rebuild/reorganize fragmented indexes in EmployeeLeaveDb',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Index_Maintenance',
    @step_name = N'Index Optimize',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Maint_IndexOptimize;',
    @retry_attempts = 1,
    @retry_interval = 10,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Weekly_Sun_0200',
    @freq_type = 8,
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 020000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Index_Maintenance',
    @schedule_name = N'ELM_Weekly_Sun_0200';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Index_Maintenance';
GO

/* ---- 2) Statistics Update — Daily 03:00 ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Statistics_Update',
    @enabled = 1,
    @description = N'Update statistics on all user tables',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Statistics_Update',
    @step_name = N'Update Statistics',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Maint_UpdateStatistics;',
    @on_success_action = 1,
    @on_fail_action = 2;
GO
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = N'ELM_Daily_0300')
    EXEC msdb.dbo.sp_add_schedule
        @schedule_name = N'ELM_Daily_0300',
        @freq_type = 4,
        @freq_interval = 1,
        @freq_subday_type = 1,
        @active_start_time = 030000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Statistics_Update',
    @schedule_name = N'ELM_Daily_0300';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Statistics_Update';
GO

/* ---- 3) Archive Execution — Monthly day 1 at 04:00 ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Archive_Execution',
    @enabled = 1,
    @description = N'Archive closed leave requests, notifications, audit logs, leave balances',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Archive_Execution',
    @step_name = N'Run Archive',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Maint_RunArchiveJob;',
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Monthly_Day1_0400',
    @freq_type = 16,
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 040000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Archive_Execution',
    @schedule_name = N'ELM_Monthly_Day1_0400';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Archive_Execution';
GO

/* ---- 4) Temporary Data Cleanup — Weekly Saturday 05:00 ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Temp_Cleanup',
    @enabled = 1,
    @description = N'Purge aged metric snapshots and temporary operational logs',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Temp_Cleanup',
    @step_name = N'Temp Cleanup',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Maint_TempDataCleanup;',
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Weekly_Sat_0500',
    @freq_type = 8,
    @freq_interval = 64,
    @freq_recurrence_factor = 1,
    @active_start_time = 050000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Temp_Cleanup',
    @schedule_name = N'ELM_Weekly_Sat_0500';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Temp_Cleanup';
GO

/* ---- 5) Database Integrity Check — Weekly Sunday 01:00 ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Integrity_Check',
    @enabled = 1,
    @description = N'DBCC CHECKDB integrity verification',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Integrity_Check',
    @step_name = N'CHECKDB',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Maint_IntegrityCheck;',
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Weekly_Sun_0100',
    @freq_type = 8,
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 010000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Integrity_Check',
    @schedule_name = N'ELM_Weekly_Sun_0100';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Integrity_Check';
GO

/* ---- 6) Metric Snapshot — Every 6 hours ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Metric_Snapshot',
    @enabled = 1,
    @description = N'Capture database size / connection / fragmentation metrics for growth reports',
    @category_name = N'Data Collector',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Metric_Snapshot',
    @step_name = N'Capture Metrics',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Monitor_CaptureMetricSnapshot;',
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Every_6_Hours',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 8,
    @freq_subday_interval = 6,
    @active_start_time = 000000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Metric_Snapshot',
    @schedule_name = N'ELM_Every_6_Hours';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Metric_Snapshot';
GO

PRINT '06_Agent_Jobs.sql completed — maintenance agent jobs created.';
GO
