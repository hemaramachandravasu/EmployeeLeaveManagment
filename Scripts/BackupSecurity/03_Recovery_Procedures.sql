/*
  Disaster Recovery Procedures
  - Point-in-time restore script generator
  - Backup integrity validation (RESTORE VERIFYONLY)
  - Recovery chain documentation helpers
*/
USE EmployeeLeaveDb;
GO

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DR_ValidateLastBackup
    @DatabaseName SYSNAME = N'EmployeeLeaveDb',
    @BackupType   NVARCHAR(20) = NULL   -- Full / Differential / Log / NULL = latest any
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Path NVARCHAR(520), @Type NVARCHAR(20), @ValidationId INT;
    DECLARE @Err NVARCHAR(4000) = NULL, @Verified BIT = 0;

    SELECT TOP (1)
        @Path = BackupPath,
        @Type = BackupType
    FROM dbo.BackupRunLog
    WHERE DatabaseName = @DatabaseName
      AND Status IN (N'Success', N'Verified')
      AND (@BackupType IS NULL OR BackupType = @BackupType)
    ORDER BY BackupRunId DESC;

    IF @Path IS NULL
        THROW 52001, N'No successful backup found to validate.', 1;

    INSERT INTO dbo.RecoveryValidationLog (DatabaseName, ValidationType, BackupPath, Status)
    VALUES (@DatabaseName, N'VerifyOnly', @Path, N'Running');
    SET @ValidationId = SCOPE_IDENTITY();

    BEGIN TRY
        RESTORE VERIFYONLY FROM DISK = @Path WITH CHECKSUM;
        SET @Verified = 1;

        UPDATE dbo.RecoveryValidationLog
        SET EndTime = SYSUTCDATETIME(),
            Status = N'Success',
            Details = N'VERIFYONLY passed for ' + @Type + N' backup.'
        WHERE ValidationId = @ValidationId;

        SELECT @ValidationId AS ValidationId, @Type AS BackupType, @Path AS BackupPath,
               N'Success' AS Status, N'VERIFYONLY with CHECKSUM passed.' AS Details;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        UPDATE dbo.RecoveryValidationLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Failed', ErrorMessage = @Err
        WHERE ValidationId = @ValidationId;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DR_GetBackupChain
    @DatabaseName SYSNAME = N'EmployeeLeaveDb',
    @HoursBack INT = 72
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        b.backup_set_id AS BackupSetId,
        CASE b.type WHEN 'D' THEN N'Full' WHEN 'I' THEN N'Differential' WHEN 'L' THEN N'Log' ELSE b.type END AS BackupType,
        b.backup_start_date AS StartTime,
        b.backup_finish_date AS EndTime,
        b.first_lsn AS FirstLsn,
        b.last_lsn AS LastLsn,
        b.checkpoint_lsn AS CheckpointLsn,
        b.database_backup_lsn AS DatabaseBackupLsn,
        CAST(b.backup_size / 1024.0 / 1024.0 AS DECIMAL(18,2)) AS BackupSizeMB,
        mf.physical_device_name AS BackupPath,
        b.is_copy_only AS IsCopyOnly,
        b.has_backup_checksums AS HasChecksum
    FROM msdb.dbo.backupset b
    INNER JOIN msdb.dbo.backupmediafamily mf ON mf.media_set_id = b.media_set_id
    WHERE b.database_name = @DatabaseName
      AND b.backup_finish_date >= DATEADD(HOUR, -@HoursBack, SYSUTCDATETIME())
    ORDER BY b.backup_finish_date;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DR_GeneratePointInTimeRestoreScript
    @DatabaseName     SYSNAME = N'EmployeeLeaveDb',
    @TargetDatabase   SYSNAME = N'EmployeeLeaveDb_PITR',
    @PointInTimeUtc   DATETIME2,
    @MoveDataPath     NVARCHAR(260) = N'C:\SQLData\',
    @MoveLogPath      NVARCHAR(260) = N'C:\SQLLogs\'
AS
BEGIN
    SET NOCOUNT ON;

    /*
      Generates a printable T-SQL restore script (does not execute restore).
      Operator reviews and runs manually on the recover instance.
    */

    DECLARE @FullPath NVARCHAR(520), @DiffPath NVARCHAR(520);
    DECLARE @FullEnd DATETIME2, @DiffEnd DATETIME2;

    SELECT TOP (1)
        @FullPath = mf.physical_device_name,
        @FullEnd = b.backup_finish_date
    FROM msdb.dbo.backupset b
    INNER JOIN msdb.dbo.backupmediafamily mf ON mf.media_set_id = b.media_set_id
    WHERE b.database_name = @DatabaseName
      AND b.type = 'D'
      AND b.is_copy_only = 0
      AND b.backup_finish_date <= @PointInTimeUtc
    ORDER BY b.backup_finish_date DESC;

    IF @FullPath IS NULL
        THROW 52002, N'No full backup found before the target point-in-time.', 1;

    SELECT TOP (1)
        @DiffPath = mf.physical_device_name,
        @DiffEnd = b.backup_finish_date
    FROM msdb.dbo.backupset b
    INNER JOIN msdb.dbo.backupmediafamily mf ON mf.media_set_id = b.media_set_id
    WHERE b.database_name = @DatabaseName
      AND b.type = 'I'
      AND b.backup_finish_date > @FullEnd
      AND b.backup_finish_date <= @PointInTimeUtc
    ORDER BY b.backup_finish_date DESC;

    DECLARE @Script NVARCHAR(MAX) = N'';
    SET @Script += N'-- Point-in-Time Recovery script for ' + QUOTENAME(@DatabaseName) + NCHAR(13) + NCHAR(10);
    SET @Script += N'-- Target PIT (UTC): ' + CONVERT(NVARCHAR(30), @PointInTimeUtc, 126) + NCHAR(13) + NCHAR(10);
    SET @Script += N'-- Generated: ' + CONVERT(NVARCHAR(30), SYSUTCDATETIME(), 126) + NCHAR(13) + NCHAR(10);
    SET @Script += N'-- REVIEW carefully before executing.' + NCHAR(13) + NCHAR(10) + NCHAR(13) + NCHAR(10);

    SET @Script += N'RESTORE DATABASE ' + QUOTENAME(@TargetDatabase) + NCHAR(13) + NCHAR(10);
    SET @Script += N'FROM DISK = N''' + REPLACE(@FullPath, '''', '''''') + N'''' + NCHAR(13) + NCHAR(10);
    SET @Script += N'WITH NORECOVERY, REPLACE,' + NCHAR(13) + NCHAR(10);
    SET @Script += N'     MOVE N''EmployeeLeaveDb'' TO N''' + @MoveDataPath + @TargetDatabase + N'.mdf'',' + NCHAR(13) + NCHAR(10);
    SET @Script += N'     MOVE N''EmployeeLeaveDb_log'' TO N''' + @MoveLogPath + @TargetDatabase + N'_log.ldf'';' + NCHAR(13) + NCHAR(10) + NCHAR(13) + NCHAR(10);

    IF @DiffPath IS NOT NULL
    BEGIN
        SET @Script += N'RESTORE DATABASE ' + QUOTENAME(@TargetDatabase) + NCHAR(13) + NCHAR(10);
        SET @Script += N'FROM DISK = N''' + REPLACE(@DiffPath, '''', '''''') + N'''' + NCHAR(13) + NCHAR(10);
        SET @Script += N'WITH NORECOVERY;' + NCHAR(13) + NCHAR(10) + NCHAR(13) + NCHAR(10);
    END

    -- Transaction log backups after last full/diff up to PIT
    DECLARE @LogPath NVARCHAR(520), @LogStart DATETIME2, @LogEnd DATETIME2;
    DECLARE @BaseTime DATETIME2 = ISNULL(@DiffEnd, @FullEnd);

    DECLARE log_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT mf.physical_device_name, b.backup_start_date, b.backup_finish_date
        FROM msdb.dbo.backupset b
        INNER JOIN msdb.dbo.backupmediafamily mf ON mf.media_set_id = b.media_set_id
        WHERE b.database_name = @DatabaseName
          AND b.type = 'L'
          AND b.backup_finish_date > @BaseTime
          AND b.backup_start_date <= @PointInTimeUtc
        ORDER BY b.backup_finish_date;

    OPEN log_cursor;
    FETCH NEXT FROM log_cursor INTO @LogPath, @LogStart, @LogEnd;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @LogEnd >= @PointInTimeUtc
        BEGIN
            SET @Script += N'RESTORE LOG ' + QUOTENAME(@TargetDatabase) + NCHAR(13) + NCHAR(10);
            SET @Script += N'FROM DISK = N''' + REPLACE(@LogPath, '''', '''''') + N'''' + NCHAR(13) + NCHAR(10);
            SET @Script += N'WITH STOPAT = ''' + CONVERT(NVARCHAR(30), @PointInTimeUtc, 126) + N''', RECOVERY;' + NCHAR(13) + NCHAR(10) + NCHAR(13) + NCHAR(10);
        END
        ELSE
        BEGIN
            SET @Script += N'RESTORE LOG ' + QUOTENAME(@TargetDatabase) + NCHAR(13) + NCHAR(10);
            SET @Script += N'FROM DISK = N''' + REPLACE(@LogPath, '''', '''''') + N'''' + NCHAR(13) + NCHAR(10);
            SET @Script += N'WITH NORECOVERY;' + NCHAR(13) + NCHAR(10) + NCHAR(13) + NCHAR(10);
        END

        FETCH NEXT FROM log_cursor INTO @LogPath, @LogStart, @LogEnd;
    END

    CLOSE log_cursor;
    DEALLOCATE log_cursor;

    SET @Script += N'-- Optional integrity validation after recovery:' + NCHAR(13) + NCHAR(10);
    SET @Script += N'-- DBCC CHECKDB (' + QUOTENAME(@TargetDatabase) + N') WITH NO_INFOMSGS;' + NCHAR(13) + NCHAR(10);

    INSERT INTO dbo.RecoveryValidationLog (DatabaseName, ValidationType, TargetPointInTime, Status, Details)
    VALUES (@DatabaseName, N'RestoreScriptGenerated', @PointInTimeUtc, N'Success',
            N'Script generated for target ' + @TargetDatabase);

    SELECT @Script AS RestoreScript,
           @FullPath AS FullBackupPath,
           @DiffPath AS DifferentialBackupPath,
           @PointInTimeUtc AS PointInTimeUtc,
           @TargetDatabase AS TargetDatabase;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DR_GetValidationHistory
    @TopN INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@TopN)
        ValidationId, DatabaseName, ValidationType, BackupPath, TargetPointInTime,
        StartTime, EndTime, Status, Details, ErrorMessage
    FROM dbo.RecoveryValidationLog
    ORDER BY ValidationId DESC;
END
GO

PRINT 'Disaster recovery procedures created.';
GO
