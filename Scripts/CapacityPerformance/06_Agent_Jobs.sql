/*
================================================================================
  SQL Server Agent Jobs — Capacity Planning & Performance Dashboard
  Requires SQL Server Agent (not available on Express).
================================================================================
*/
USE msdb;
GO

DECLARE @Jobs TABLE (JobName SYSNAME);
INSERT INTO @Jobs (JobName) VALUES
    (N'ELM_CapPerf_CollectMetrics'),
    (N'ELM_CapPerf_RefreshDashboard'),
    (N'ELM_CapPerf_AlertScan'),
    (N'ELM_CapPerf_ArchiveHistory');

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

/* ---- 1) Collect monitoring data — every 6 hours ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_CapPerf_CollectMetrics',
    @enabled = 1,
    @description = N'Capture size/volume metrics and capacity forecast',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_CapPerf_CollectMetrics',
    @step_name = N'Capture Metrics',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Cap_CaptureMetricSnapshot;',
    @retry_attempts = 1,
    @retry_interval = 5,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_CapPerf_Every_6_Hours',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 8,
    @freq_subday_interval = 6,
    @active_start_time = 001500;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_CapPerf_CollectMetrics',
    @schedule_name = N'ELM_CapPerf_Every_6_Hours';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_CapPerf_CollectMetrics';
GO

/* ---- 2) Refresh dashboard metrics (waits + resource) — every 2 hours ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_CapPerf_RefreshDashboard',
    @enabled = 1,
    @description = N'Persist wait-stat snapshot for dashboard trends',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_CapPerf_RefreshDashboard',
    @step_name = N'Wait Snapshot',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Perf_WaitStatistics @TopN = 25, @PersistSnapshot = 1; EXEC dbo.sp_Perf_ResourceConsumptionSummary;',
    @retry_attempts = 0,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_CapPerf_Every_2_Hours',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 8,
    @freq_subday_interval = 2,
    @active_start_time = 003000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_CapPerf_RefreshDashboard',
    @schedule_name = N'ELM_CapPerf_Every_2_Hours';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_CapPerf_RefreshDashboard';
GO

/* ---- 3) Alert scan — every 2 hours ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_CapPerf_AlertScan',
    @enabled = 1,
    @description = N'Scan storage, fragmentation, slow queries, failed jobs, capacity thresholds',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_CapPerf_AlertScan',
    @step_name = N'Run Alerts',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_CapPerf_RunAllAlerts;',
    @retry_attempts = 0,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_CapPerf_AlertScan',
    @schedule_name = N'ELM_CapPerf_Every_2_Hours';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_CapPerf_AlertScan';
GO

/* ---- 4) Archive historical monitoring data — weekly Sunday 05:00 ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_CapPerf_ArchiveHistory',
    @enabled = 1,
    @description = N'Archive/purge aged metric, wait, forecast, and acknowledged alert history',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_CapPerf_ArchiveHistory',
    @step_name = N'Archive History',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_CapPerf_ArchiveHistoricalData;',
    @retry_attempts = 0,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_CapPerf_Weekly_Sun_0500',
    @freq_type = 8,
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 050000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_CapPerf_ArchiveHistory',
    @schedule_name = N'ELM_CapPerf_Weekly_Sun_0500';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_CapPerf_ArchiveHistory';
GO

PRINT 'CapacityPerformance Agent jobs created.';
GO
