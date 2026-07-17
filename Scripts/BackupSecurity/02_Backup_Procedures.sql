/*
  Backup Automation Stored Procedures
*/
USE EmployeeLeaveDb;
GO

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Backup_GetConfig
    @DatabaseName SYSNAME = N'EmployeeLeaveDb'
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ConfigId, DatabaseName, BackupRootPath, FullRetentionDays, DiffRetentionDays,
           LogRetentionDays, VerifyAfterBackup, IsEnabled, LastModifiedUtc
    FROM dbo.BackupConfig
    WHERE DatabaseName = @DatabaseName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Backup_EnsureDirectory
    @Path NVARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;
    -- Intentionally no xp_cmdshell: create BackupRootPath on the host before first run.
    -- Example: mkdir C:\Backup\EmployeeLeaveDb
    IF @Path IS NULL OR LEN(@Path) < 3
        THROW 51000, N'BackupRootPath is invalid.', 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Backup_LogStart
    @DatabaseName SYSNAME,
    @BackupType   NVARCHAR(20),
    @BackupPath   NVARCHAR(520),
    @BackupRunId  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.BackupRunLog (DatabaseName, BackupType, BackupPath, Status)
    VALUES (@DatabaseName, @BackupType, @BackupPath, N'Running');
    SET @BackupRunId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Backup_LogEnd
    @BackupRunId  INT,
    @Status       NVARCHAR(20),
    @BackupSizeMB DECIMAL(18,2) = NULL,
    @Verified     BIT = 0,
    @ErrorMessage NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.BackupRunLog
    SET EndTime = SYSUTCDATETIME(),
        Status = @Status,
        BackupSizeMB = @BackupSizeMB,
        Verified = @Verified,
        DurationSeconds = DATEDIFF(SECOND, StartTime, SYSUTCDATETIME()),
        ErrorMessage = @ErrorMessage
    WHERE BackupRunId = @BackupRunId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Backup_VerifyFile
    @BackupPath NVARCHAR(520),
    @Verified   BIT OUTPUT,
    @ErrorMessage NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Verified = 0;
    SET @ErrorMessage = NULL;

    BEGIN TRY
        RESTORE VERIFYONLY FROM DISK = @BackupPath WITH CHECKSUM;
        SET @Verified = 1;
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @Verified = 0;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Backup_Full
    @DatabaseName SYSNAME = N'EmployeeLeaveDb',
    @SkipVerify   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Root NVARCHAR(260), @Verify BIT, @Enabled BIT;
    DECLARE @Path NVARCHAR(520), @Stamp NVARCHAR(30), @RunId INT;
    DECLARE @SizeMB DECIMAL(18,2) = NULL, @Verified BIT = 0, @Err NVARCHAR(4000) = NULL;

    SELECT @Root = BackupRootPath, @Verify = VerifyAfterBackup, @Enabled = IsEnabled
    FROM dbo.BackupConfig WHERE DatabaseName = @DatabaseName;

    IF @Enabled IS NULL OR @Enabled = 0
        THROW 51001, N'Backup is disabled or config missing for database.', 1;

    SET @Stamp = FORMAT(SYSUTCDATETIME(), 'yyyyMMdd_HHmmss');
    SET @Path = @Root + @DatabaseName + N'_FULL_' + @Stamp + N'.bak';

    EXEC dbo.sp_Backup_EnsureDirectory @Root;
    EXEC dbo.sp_Backup_LogStart @DatabaseName, N'Full', @Path, @RunId OUTPUT;

    BEGIN TRY
        BACKUP DATABASE @DatabaseName
            TO DISK = @Path
            WITH INIT, CHECKSUM, COMPRESSION, STATS = 10;

        SELECT TOP (1) @SizeMB = CAST(backup_size / 1024.0 / 1024.0 AS DECIMAL(18,2))
        FROM msdb.dbo.backupset
        WHERE database_name = @DatabaseName AND type = 'D'
        ORDER BY backup_finish_date DESC;

        IF @Verify = 1 AND @SkipVerify = 0
            EXEC dbo.sp_Backup_VerifyFile @Path, @Verified OUTPUT, @Err OUTPUT;

        IF @Verify = 1 AND @SkipVerify = 0 AND @Verified = 0
        BEGIN
            EXEC dbo.sp_Backup_LogEnd @RunId, N'Failed', @SizeMB, 0, @Err;
            THROW 51002, @Err, 1;
        END

        DECLARE @FinalStatus NVARCHAR(20) = CASE WHEN @Verified = 1 THEN N'Verified' ELSE N'Success' END;
        EXEC dbo.sp_Backup_LogEnd @RunId, @FinalStatus, @SizeMB, @Verified, NULL;

        SELECT @RunId AS BackupRunId, N'Full' AS BackupType, @Path AS BackupPath,
               @FinalStatus AS Status,
               @SizeMB AS BackupSizeMB, @Verified AS Verified;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC dbo.sp_Backup_LogEnd @RunId, N'Failed', NULL, 0, @Err;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Backup_Differential
    @DatabaseName SYSNAME = N'EmployeeLeaveDb',
    @SkipVerify   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Root NVARCHAR(260), @Verify BIT, @Enabled BIT;
    DECLARE @Path NVARCHAR(520), @Stamp NVARCHAR(30), @RunId INT;
    DECLARE @SizeMB DECIMAL(18,2) = NULL, @Verified BIT = 0, @Err NVARCHAR(4000) = NULL;

    SELECT @Root = BackupRootPath, @Verify = VerifyAfterBackup, @Enabled = IsEnabled
    FROM dbo.BackupConfig WHERE DatabaseName = @DatabaseName;

    IF @Enabled IS NULL OR @Enabled = 0
        THROW 51001, N'Backup is disabled or config missing for database.', 1;

    IF NOT EXISTS (
        SELECT 1 FROM msdb.dbo.backupset
        WHERE database_name = @DatabaseName AND type = 'D' AND is_copy_only = 0)
        THROW 51003, N'No prior full backup found. Run sp_Backup_Full first.', 1;

    SET @Stamp = FORMAT(SYSUTCDATETIME(), 'yyyyMMdd_HHmmss');
    SET @Path = @Root + @DatabaseName + N'_DIFF_' + @Stamp + N'.bak';

    EXEC dbo.sp_Backup_EnsureDirectory @Root;
    EXEC dbo.sp_Backup_LogStart @DatabaseName, N'Differential', @Path, @RunId OUTPUT;

    BEGIN TRY
        BACKUP DATABASE @DatabaseName
            TO DISK = @Path
            WITH DIFFERENTIAL, INIT, CHECKSUM, COMPRESSION, STATS = 10;

        SELECT TOP (1) @SizeMB = CAST(backup_size / 1024.0 / 1024.0 AS DECIMAL(18,2))
        FROM msdb.dbo.backupset
        WHERE database_name = @DatabaseName AND type = 'I'
        ORDER BY backup_finish_date DESC;

        IF @Verify = 1 AND @SkipVerify = 0
            EXEC dbo.sp_Backup_VerifyFile @Path, @Verified OUTPUT, @Err OUTPUT;

        IF @Verify = 1 AND @SkipVerify = 0 AND @Verified = 0
        BEGIN
            EXEC dbo.sp_Backup_LogEnd @RunId, N'Failed', @SizeMB, 0, @Err;
            THROW 51002, @Err, 1;
        END

        DECLARE @FinalStatusDiff NVARCHAR(20) = CASE WHEN @Verified = 1 THEN N'Verified' ELSE N'Success' END;
        EXEC dbo.sp_Backup_LogEnd @RunId, @FinalStatusDiff, @SizeMB, @Verified, NULL;

        SELECT @RunId AS BackupRunId, N'Differential' AS BackupType, @Path AS BackupPath,
               @FinalStatusDiff AS Status,
               @SizeMB AS BackupSizeMB, @Verified AS Verified;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC dbo.sp_Backup_LogEnd @RunId, N'Failed', NULL, 0, @Err;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Backup_Log
    @DatabaseName SYSNAME = N'EmployeeLeaveDb',
    @SkipVerify   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Root NVARCHAR(260), @Verify BIT, @Enabled BIT;
    DECLARE @Path NVARCHAR(520), @Stamp NVARCHAR(30), @RunId INT;
    DECLARE @SizeMB DECIMAL(18,2) = NULL, @Verified BIT = 0, @Err NVARCHAR(4000) = NULL;

    SELECT @Root = BackupRootPath, @Verify = VerifyAfterBackup, @Enabled = IsEnabled
    FROM dbo.BackupConfig WHERE DatabaseName = @DatabaseName;

    IF @Enabled IS NULL OR @Enabled = 0
        THROW 51001, N'Backup is disabled or config missing for database.', 1;

    IF (SELECT recovery_model_desc FROM sys.databases WHERE name = @DatabaseName) <> N'FULL'
        THROW 51004, N'Database must be in FULL recovery model for transaction log backups.', 1;

    SET @Stamp = FORMAT(SYSUTCDATETIME(), 'yyyyMMdd_HHmmss');
    SET @Path = @Root + @DatabaseName + N'_LOG_' + @Stamp + N'.trn';

    EXEC dbo.sp_Backup_EnsureDirectory @Root;
    EXEC dbo.sp_Backup_LogStart @DatabaseName, N'Log', @Path, @RunId OUTPUT;

    BEGIN TRY
        BACKUP LOG @DatabaseName
            TO DISK = @Path
            WITH INIT, CHECKSUM, COMPRESSION, STATS = 5;

        SELECT TOP (1) @SizeMB = CAST(backup_size / 1024.0 / 1024.0 AS DECIMAL(18,2))
        FROM msdb.dbo.backupset
        WHERE database_name = @DatabaseName AND type = 'L'
        ORDER BY backup_finish_date DESC;

        IF @Verify = 1 AND @SkipVerify = 0
            EXEC dbo.sp_Backup_VerifyFile @Path, @Verified OUTPUT, @Err OUTPUT;

        DECLARE @FinalStatusLog NVARCHAR(20) = CASE WHEN @Verified = 1 THEN N'Verified' ELSE N'Success' END;
        EXEC dbo.sp_Backup_LogEnd @RunId, @FinalStatusLog, @SizeMB, @Verified, @Err;

        SELECT @RunId AS BackupRunId, N'Log' AS BackupType, @Path AS BackupPath,
               @FinalStatusLog AS Status,
               @SizeMB AS BackupSizeMB, @Verified AS Verified;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC dbo.sp_Backup_LogEnd @RunId, N'Failed', NULL, 0, @Err;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Backup_PurgeOldFiles
    @DatabaseName SYSNAME = N'EmployeeLeaveDb'
AS
BEGIN
    SET NOCOUNT ON;
    -- Retention metadata only; physical file deletion can be handled by Agent CmdExec / Ops.
    -- Returns candidates older than configured retention.

    DECLARE @FullDays INT, @DiffDays INT, @LogDays INT;
    SELECT @FullDays = FullRetentionDays, @DiffDays = DiffRetentionDays, @LogDays = LogRetentionDays
    FROM dbo.BackupConfig WHERE DatabaseName = @DatabaseName;

    SELECT BackupRunId, BackupType, BackupPath, StartTime, Status, BackupSizeMB
    FROM dbo.BackupRunLog
    WHERE DatabaseName = @DatabaseName
      AND Status IN (N'Success', N'Verified')
      AND (
            (BackupType = N'Full' AND StartTime < DATEADD(DAY, -@FullDays, SYSUTCDATETIME()))
         OR (BackupType = N'Differential' AND StartTime < DATEADD(DAY, -@DiffDays, SYSUTCDATETIME()))
         OR (BackupType = N'Log' AND StartTime < DATEADD(DAY, -@LogDays, SYSUTCDATETIME()))
      )
    ORDER BY StartTime;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Backup_GetHistory
    @DatabaseName SYSNAME = N'EmployeeLeaveDb',
    @TopN INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@TopN)
        BackupRunId, DatabaseName, BackupType, BackupPath, StartTime, EndTime,
        Status, BackupSizeMB, Verified, DurationSeconds, ErrorMessage
    FROM dbo.BackupRunLog
    WHERE DatabaseName = @DatabaseName
    ORDER BY BackupRunId DESC;

    -- Also return recent msdb history for cross-check
    SELECT TOP (@TopN)
        b.backup_set_id AS BackupSetId,
        b.database_name AS DatabaseName,
        CASE b.type WHEN 'D' THEN N'Full' WHEN 'I' THEN N'Differential' WHEN 'L' THEN N'Log' ELSE b.type END AS BackupType,
        b.backup_start_date AS StartTime,
        b.backup_finish_date AS EndTime,
        CAST(b.backup_size / 1024.0 / 1024.0 AS DECIMAL(18,2)) AS BackupSizeMB,
        mf.physical_device_name AS BackupPath,
        b.is_damaged AS IsDamaged
    FROM msdb.dbo.backupset b
    INNER JOIN msdb.dbo.backupmediafamily mf ON mf.media_set_id = b.media_set_id
    WHERE b.database_name = @DatabaseName
    ORDER BY b.backup_finish_date DESC;
END
GO

PRINT 'Backup procedures created.';
GO
