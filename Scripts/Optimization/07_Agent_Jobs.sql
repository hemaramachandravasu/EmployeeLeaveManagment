/*
================================================================================
  SQL Server Agent Jobs — Database Optimization & Partition Care
  Requires SQL Server Agent (not available on Express).
================================================================================
*/
USE msdb;
GO

DECLARE @Jobs TABLE (JobName SYSNAME);
INSERT INTO @Jobs (JobName) VALUES
    (N'ELM_Opt_Index_Maintenance'),
    (N'ELM_Opt_Statistics_Update'),
    (N'ELM_Opt_Health_Check'),
    (N'ELM_Opt_Partition_Manage'),
    (N'ELM_Opt_Performance_Snapshot');

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

/* ---- 1) Partition-aware Index Maintenance — Sunday 02:30 ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Opt_Index_Maintenance',
    @enabled = 1,
    @description = N'Partition-aware rebuild/reorganize for EmployeeLeaveDb',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Opt_Index_Maintenance',
    @step_name = N'Opt Index Rebuild/Reorganize',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Opt_IndexRebuildReorganize @RebuildThresholdPercent = 30, @ReorganizeThresholdPercent = 10, @MinPageCount = 50;',
    @retry_attempts = 1,
    @retry_interval = 10,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Opt_Weekly_Sun_0230',
    @freq_type = 8,
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 023000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Opt_Index_Maintenance',
    @schedule_name = N'ELM_Opt_Weekly_Sun_0230';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Opt_Index_Maintenance';
GO

/* ---- 2) Statistics Update — Daily 03:30 ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Opt_Statistics_Update',
    @enabled = 1,
    @description = N'Update statistics for EmployeeLeaveDb (optimization module)',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Opt_Statistics_Update',
    @step_name = N'Update Statistics',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Opt_UpdateStatistics @FullScan = 0;',
    @retry_attempts = 1,
    @retry_interval = 5,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Opt_Daily_0330',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 033000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Opt_Statistics_Update',
    @schedule_name = N'ELM_Opt_Daily_0330';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Opt_Statistics_Update';
GO

/* ---- 3) Database Health Check — Daily 06:00 ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Opt_Health_Check',
    @enabled = 1,
    @description = N'Optimization health check (fragmentation + partition headroom)',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Opt_Health_Check',
    @step_name = N'Health Check',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Opt_DatabaseHealthCheck;',
    @retry_attempts = 0,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Opt_Daily_0600',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 060000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Opt_Health_Check',
    @schedule_name = N'ELM_Opt_Daily_0600';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Opt_Health_Check';
GO

/* ---- 4) Partition boundary care — 1st of month 01:00 ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Opt_Partition_Manage',
    @enabled = 1,
    @description = N'Health check + auto SPLIT leave/audit partitions when near capacity',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Opt_Partition_Manage',
    @step_name = N'Partition Care',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Opt_RunScheduledHealthAndPartitionCare @AutoSplit = 1;',
    @retry_attempts = 1,
    @retry_interval = 10,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Opt_Monthly_Day1_0100',
    @freq_type = 16,
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 010000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Opt_Partition_Manage',
    @schedule_name = N'ELM_Opt_Monthly_Day1_0100';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Opt_Partition_Manage';
GO

/* ---- 5) Performance monitoring snapshot — every 6 hours ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Opt_Performance_Snapshot',
    @enabled = 1,
    @description = N'Capture metric snapshot (reuses Maintenance sp_Monitor_CaptureMetricSnapshot when present)',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Opt_Performance_Snapshot',
    @step_name = N'Capture Metrics',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'
IF OBJECT_ID(N''dbo.sp_Monitor_CaptureMetricSnapshot'', N''P'') IS NOT NULL
    EXEC dbo.sp_Monitor_CaptureMetricSnapshot;
ELSE
    EXEC dbo.sp_Opt_Report_PerformanceSummary;
',
    @retry_attempts = 0,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Opt_Every_6_Hours',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 8,
    @freq_subday_interval = 6,
    @active_start_time = 000000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Opt_Performance_Snapshot',
    @schedule_name = N'ELM_Opt_Every_6_Hours';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Opt_Performance_Snapshot';
GO

PRINT 'Optimization Agent jobs created.';
GO
