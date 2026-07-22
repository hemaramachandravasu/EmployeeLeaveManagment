/*
================================================================================
  SQL Server Agent Jobs — Audit / Integrity / Compliance
  Requires SQL Server Agent (not available on Express).
================================================================================
*/
USE msdb;
GO

DECLARE @Jobs TABLE (JobName SYSNAME);
INSERT INTO @Jobs (JobName) VALUES
    (N'ELM_Compliance_Integrity_Checks'),
    (N'ELM_Compliance_Status_Monitor'),
    (N'ELM_Audit_Activity_Retention');

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

/* ---- 1) Full integrity validation — Daily 05:00 ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Compliance_Integrity_Checks',
    @enabled = 1,
    @description = N'Run all data integrity validation checks and log violations',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Compliance_Integrity_Checks',
    @step_name = N'Run Integrity Checks',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'EXEC dbo.sp_Compliance_RunScheduledAuditJob;',
    @retry_attempts = 1,
    @retry_interval = 5,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Compliance_Daily_0500',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 050000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Compliance_Integrity_Checks',
    @schedule_name = N'ELM_Compliance_Daily_0500';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Compliance_Integrity_Checks';
GO

/* ---- 2) Compliance status monitor — Every 6 hours ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Compliance_Status_Monitor',
    @enabled = 1,
    @description = N'Capture compliance status snapshot (writes ComplianceRunLog via health path)',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Compliance_Status_Monitor',
    @step_name = N'Compliance Status',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'
DECLARE @RunId INT;
EXEC dbo.sp_Compliance_LogStart N''ELM_Compliance_Status_Monitor'', N''StatusSnapshot'', @RunId OUTPUT;
EXEC dbo.sp_Monitor_ComplianceStatus;
EXEC dbo.sp_Compliance_LogEnd @RunId = @RunId, @Status = N''Success'', @Details = N''Compliance status snapshot captured.'';
',
    @retry_attempts = 0,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Compliance_Every_6_Hours',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 8,
    @freq_subday_interval = 6,
    @active_start_time = 000500;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Compliance_Status_Monitor',
    @schedule_name = N'ELM_Compliance_Every_6_Hours';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Compliance_Status_Monitor';
GO

/* ---- 3) Activity retention cleanup — Weekly Sunday 04:30 ---- */
EXEC msdb.dbo.sp_add_job
    @job_name = N'ELM_Audit_Activity_Retention',
    @enabled = 1,
    @description = N'Purge old user activity and resolved low-severity integrity findings',
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ELM_Audit_Activity_Retention',
    @step_name = N'Retention Cleanup',
    @subsystem = N'TSQL',
    @database_name = N'EmployeeLeaveDb',
    @command = N'
DECLARE @RunId INT;
EXEC dbo.sp_Compliance_LogStart N''ELM_Audit_Activity_Retention'', N''RetentionCleanup'', @RunId OUTPUT;
BEGIN TRY
    DELETE FROM dbo.UserActivityLog WHERE ActivityAt < DATEADD(DAY, -180, SYSUTCDATETIME());
    DECLARE @Act INT = @@ROWCOUNT;
    DELETE FROM dbo.DatabaseExceptionLog WHERE CapturedAt < DATEADD(DAY, -90, SYSUTCDATETIME());
    DECLARE @Ex INT = @@ROWCOUNT;
    DELETE FROM dbo.IntegrityViolationLog
    WHERE IsResolved = 1 AND Severity IN (N''Low'', N''Medium'')
      AND ResolvedAt < DATEADD(DAY, -90, SYSUTCDATETIME());
    DECLARE @Viol INT = @@ROWCOUNT;
    EXEC dbo.sp_Compliance_LogEnd @RunId = @RunId, @Status = N''Success'',
        @Details = CONCAT(N''Deleted activity='', @Act, N'' exceptions='', @Ex, N'' resolved violations='', @Viol);
END TRY
BEGIN CATCH
    EXEC dbo.sp_Audit_LogException
        @SourceProc = N''ELM_Audit_Activity_Retention'',
        @ErrorNumber = ERROR_NUMBER(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE(),
        @ErrorMessage = ERROR_MESSAGE();
    EXEC dbo.sp_Compliance_LogEnd @RunId = @RunId, @Status = N''Failed'', @ErrorMessage = ERROR_MESSAGE();
    THROW;
END CATCH
',
    @retry_attempts = 0,
    @on_success_action = 1,
    @on_fail_action = 2;
GO
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'ELM_Audit_Weekly_Sun_0430',
    @freq_type = 8,
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 043000;
GO
EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ELM_Audit_Activity_Retention',
    @schedule_name = N'ELM_Audit_Weekly_Sun_0430';
GO
EXEC msdb.dbo.sp_add_jobserver @job_name = N'ELM_Audit_Activity_Retention';
GO

PRINT 'AuditIntegrity Agent jobs created.';
GO
