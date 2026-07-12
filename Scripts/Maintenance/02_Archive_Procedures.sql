/*
================================================================================
  Archive & Restore Stored Procedures
  Database: EmployeeLeaveDb
================================================================================
  Secure move: INSERT into archive → verify counts → DELETE from OLTP
  within a transaction. Restoration reverses the flow by ArchiveBatchId
  or by date range / entity keys.
================================================================================
*/
USE EmployeeLeaveDb;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Archive_GetRetentionDays
    @EntityName    NVARCHAR(100),
    @RetentionDays INT OUTPUT,
    @IsEnabled     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        @RetentionDays = RetentionDays,
        @IsEnabled = IsEnabled
    FROM dbo.ArchiveRetentionConfig
    WHERE EntityName = @EntityName;

    IF @RetentionDays IS NULL
    BEGIN
        SET @RetentionDays = 730;
        SET @IsEnabled = 0;
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Archive_UpdateRetention
    @EntityName    NVARCHAR(100),
    @RetentionDays INT,
    @IsEnabled     BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @RetentionDays < 30
        THROW 50001, N'RetentionDays must be at least 30.', 1;

    UPDATE dbo.ArchiveRetentionConfig
    SET RetentionDays = @RetentionDays,
        IsEnabled = @IsEnabled,
        LastModifiedUtc = SYSUTCDATETIME()
    WHERE EntityName = @EntityName;

    IF @@ROWCOUNT = 0
        THROW 50002, N'Unknown EntityName in ArchiveRetentionConfig.', 1;

    SELECT EntityName, RetentionDays, IsEnabled, Description, LastModifiedUtc
    FROM dbo.ArchiveRetentionConfig
    WHERE EntityName = @EntityName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Archive_ClosedLeaveRequests
    @RetentionDaysOverride INT = NULL,
    @BatchId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RetentionDays INT, @IsEnabled BIT, @Cutoff DATE, @Rows INT = 0;
    DECLARE @ArchiveBatchId UNIQUEIDENTIFIER = ISNULL(@BatchId, NEWID());
    DECLARE @RunId INT;

    EXEC dbo.sp_Archive_GetRetentionDays N'LeaveRequests', @RetentionDays OUTPUT, @IsEnabled OUTPUT;
    IF @RetentionDaysOverride IS NOT NULL SET @RetentionDays = @RetentionDaysOverride;
    IF @IsEnabled = 0 AND @RetentionDaysOverride IS NULL
    BEGIN
        SELECT @ArchiveBatchId AS ArchiveBatchId, 0 AS RowsArchived, N'Skipped (disabled)' AS Status;
        RETURN;
    END

    SET @Cutoff = DATEADD(DAY, -@RetentionDays, CAST(SYSUTCDATETIME() AS DATE));

    INSERT INTO dbo.ArchiveRunLog (ArchiveBatchId, EntityName, RetentionDays, Status)
    VALUES (@ArchiveBatchId, N'LeaveRequests', @RetentionDays, N'Running');
    SET @RunId = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRAN;

        ;WITH Candidates AS (
            SELECT lr.*
            FROM dbo.LeaveRequests lr
            WHERE lr.Status IN (N'Approved', N'Rejected')
              AND lr.EndDate < @Cutoff
              AND NOT EXISTS (
                  SELECT 1 FROM dbo.LeaveRequestsArchive a
                  WHERE a.LeaveRequestId = lr.LeaveRequestId)
        )
        INSERT INTO dbo.LeaveRequestsArchive (
            LeaveRequestId, EmployeeId, LeaveTypeId, StartDate, EndDate, TotalDays,
            Reason, Status, ApprovedBy, ApprovedDate, Remarks, IsCancelled,
            CreatedDate, ModifiedDate, ArchivedAt, ArchiveBatchId)
        SELECT
            LeaveRequestId, EmployeeId, LeaveTypeId, StartDate, EndDate, TotalDays,
            Reason, Status, ApprovedBy, ApprovedDate, Remarks, IsCancelled,
            CreatedDate, ModifiedDate, SYSUTCDATETIME(), @ArchiveBatchId
        FROM Candidates;

        SET @Rows = @@ROWCOUNT;

        DELETE lr
        FROM dbo.LeaveRequests lr
        INNER JOIN dbo.LeaveRequestsArchive a
            ON a.LeaveRequestId = lr.LeaveRequestId
           AND a.ArchiveBatchId = @ArchiveBatchId;

        COMMIT TRAN;

        UPDATE dbo.ArchiveRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Success', RowsArchived = @Rows
        WHERE ArchiveRunId = @RunId;

        SELECT @ArchiveBatchId AS ArchiveBatchId, @Rows AS RowsArchived, N'Success' AS Status;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        UPDATE dbo.ArchiveRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Failed',
            ErrorMessage = ERROR_MESSAGE(), RowsArchived = 0
        WHERE ArchiveRunId = @RunId;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Archive_Notifications
    @RetentionDaysOverride INT = NULL,
    @BatchId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RetentionDays INT, @IsEnabled BIT, @Cutoff DATETIME2, @Rows INT = 0;
    DECLARE @ArchiveBatchId UNIQUEIDENTIFIER = ISNULL(@BatchId, NEWID());
    DECLARE @RunId INT;

    EXEC dbo.sp_Archive_GetRetentionDays N'Notifications', @RetentionDays OUTPUT, @IsEnabled OUTPUT;
    IF @RetentionDaysOverride IS NOT NULL SET @RetentionDays = @RetentionDaysOverride;
    IF @IsEnabled = 0 AND @RetentionDaysOverride IS NULL
    BEGIN
        SELECT @ArchiveBatchId AS ArchiveBatchId, 0 AS RowsArchived, N'Skipped (disabled)' AS Status;
        RETURN;
    END

    SET @Cutoff = DATEADD(DAY, -@RetentionDays, SYSUTCDATETIME());

    INSERT INTO dbo.ArchiveRunLog (ArchiveBatchId, EntityName, RetentionDays, Status)
    VALUES (@ArchiveBatchId, N'Notifications', @RetentionDays, N'Running');
    SET @RunId = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO dbo.NotificationsArchive (
            NotificationId, EmployeeId, Title, MessageBody, NotificationType,
            IsRead, CreatedAt, ArchivedAt, ArchiveBatchId)
        SELECT
            n.NotificationId, n.EmployeeId, n.Title, n.MessageBody, n.NotificationType,
            n.IsRead, n.CreatedAt, SYSUTCDATETIME(), @ArchiveBatchId
        FROM dbo.Notifications n
        WHERE n.IsRead = 1
          AND n.CreatedAt < @Cutoff
          AND NOT EXISTS (
              SELECT 1 FROM dbo.NotificationsArchive a
              WHERE a.NotificationId = n.NotificationId);

        SET @Rows = @@ROWCOUNT;

        DELETE n
        FROM dbo.Notifications n
        INNER JOIN dbo.NotificationsArchive a
            ON a.NotificationId = n.NotificationId
           AND a.ArchiveBatchId = @ArchiveBatchId;

        COMMIT TRAN;

        UPDATE dbo.ArchiveRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Success', RowsArchived = @Rows
        WHERE ArchiveRunId = @RunId;

        SELECT @ArchiveBatchId AS ArchiveBatchId, @Rows AS RowsArchived, N'Success' AS Status;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        UPDATE dbo.ArchiveRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Failed',
            ErrorMessage = ERROR_MESSAGE(), RowsArchived = 0
        WHERE ArchiveRunId = @RunId;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Archive_AuditLogs
    @RetentionDaysOverride INT = NULL,
    @BatchId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RetentionDays INT, @IsEnabled BIT, @Cutoff DATETIME2, @Rows INT = 0;
    DECLARE @ArchiveBatchId UNIQUEIDENTIFIER = ISNULL(@BatchId, NEWID());
    DECLARE @RunId INT;

    EXEC dbo.sp_Archive_GetRetentionDays N'AuditLogs', @RetentionDays OUTPUT, @IsEnabled OUTPUT;
    IF @RetentionDaysOverride IS NOT NULL SET @RetentionDays = @RetentionDaysOverride;
    IF @IsEnabled = 0 AND @RetentionDaysOverride IS NULL
    BEGIN
        SELECT @ArchiveBatchId AS ArchiveBatchId, 0 AS RowsArchived, N'Skipped (disabled)' AS Status;
        RETURN;
    END

    SET @Cutoff = DATEADD(DAY, -@RetentionDays, SYSUTCDATETIME());

    INSERT INTO dbo.ArchiveRunLog (ArchiveBatchId, EntityName, RetentionDays, Status)
    VALUES (@ArchiveBatchId, N'AuditLogs', @RetentionDays, N'Running');
    SET @RunId = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO dbo.AuditLogsArchive (
            AuditId, TableName, RecordId, ActionType, OldValue, NewValue,
            ChangedBy, ChangedOn, ArchivedAt, ArchiveBatchId)
        SELECT
            a.AuditId, a.TableName, a.RecordId, a.ActionType, a.OldValue, a.NewValue,
            a.ChangedBy, a.ChangedOn, SYSUTCDATETIME(), @ArchiveBatchId
        FROM dbo.AuditLogs a
        WHERE a.ChangedOn < @Cutoff
          AND NOT EXISTS (
              SELECT 1 FROM dbo.AuditLogsArchive x WHERE x.AuditId = a.AuditId);

        SET @Rows = @@ROWCOUNT;

        DELETE a
        FROM dbo.AuditLogs a
        INNER JOIN dbo.AuditLogsArchive x
            ON x.AuditId = a.AuditId
           AND x.ArchiveBatchId = @ArchiveBatchId;

        COMMIT TRAN;

        UPDATE dbo.ArchiveRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Success', RowsArchived = @Rows
        WHERE ArchiveRunId = @RunId;

        SELECT @ArchiveBatchId AS ArchiveBatchId, @Rows AS RowsArchived, N'Success' AS Status;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        UPDATE dbo.ArchiveRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Failed',
            ErrorMessage = ERROR_MESSAGE(), RowsArchived = 0
        WHERE ArchiveRunId = @RunId;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Archive_LeaveBalances
    @RetentionDaysOverride INT = NULL,
    @BatchId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RetentionDays INT, @IsEnabled BIT, @Cutoff DATETIME2, @Rows INT = 0;
    DECLARE @ArchiveBatchId UNIQUEIDENTIFIER = ISNULL(@BatchId, NEWID());
    DECLARE @RunId INT;

    EXEC dbo.sp_Archive_GetRetentionDays N'LeaveBalances', @RetentionDays OUTPUT, @IsEnabled OUTPUT;
    IF @RetentionDaysOverride IS NOT NULL SET @RetentionDays = @RetentionDaysOverride;
    IF @IsEnabled = 0 AND @RetentionDaysOverride IS NULL
    BEGIN
        SELECT @ArchiveBatchId AS ArchiveBatchId, 0 AS RowsArchived, N'Skipped (disabled)' AS Status;
        RETURN;
    END

    SET @Cutoff = DATEADD(DAY, -@RetentionDays, SYSUTCDATETIME());

    INSERT INTO dbo.ArchiveRunLog (ArchiveBatchId, EntityName, RetentionDays, Status)
    VALUES (@ArchiveBatchId, N'LeaveBalances', @RetentionDays, N'Running');
    SET @RunId = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO dbo.LeaveBalancesArchive (
            LeaveBalanceId, EmployeeId, LeaveTypeId, BalanceYear, EntitledDays,
            UsedDays, RemainingDays, IsHistorical, CreatedAt, ClosedAt,
            ArchivedAt, ArchiveBatchId)
        SELECT
            b.LeaveBalanceId, b.EmployeeId, b.LeaveTypeId, b.BalanceYear, b.EntitledDays,
            b.UsedDays, b.RemainingDays, b.IsHistorical, b.CreatedAt, b.ClosedAt,
            SYSUTCDATETIME(), @ArchiveBatchId
        FROM dbo.LeaveBalances b
        WHERE b.IsHistorical = 1
          AND ISNULL(b.ClosedAt, b.CreatedAt) < @Cutoff
          AND NOT EXISTS (
              SELECT 1 FROM dbo.LeaveBalancesArchive x WHERE x.LeaveBalanceId = b.LeaveBalanceId);

        SET @Rows = @@ROWCOUNT;

        DELETE b
        FROM dbo.LeaveBalances b
        INNER JOIN dbo.LeaveBalancesArchive x
            ON x.LeaveBalanceId = b.LeaveBalanceId
           AND x.ArchiveBatchId = @ArchiveBatchId;

        COMMIT TRAN;

        UPDATE dbo.ArchiveRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Success', RowsArchived = @Rows
        WHERE ArchiveRunId = @RunId;

        SELECT @ArchiveBatchId AS ArchiveBatchId, @Rows AS RowsArchived, N'Success' AS Status;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        UPDATE dbo.ArchiveRunLog
        SET EndTime = SYSUTCDATETIME(), Status = N'Failed',
            ErrorMessage = ERROR_MESSAGE(), RowsArchived = 0
        WHERE ArchiveRunId = @RunId;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Archive_RunAll
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BatchId UNIQUEIDENTIFIER = NEWID();

    EXEC dbo.sp_Archive_ClosedLeaveRequests @BatchId = @BatchId;
    EXEC dbo.sp_Archive_Notifications @BatchId = @BatchId;
    EXEC dbo.sp_Archive_AuditLogs @BatchId = @BatchId;
    EXEC dbo.sp_Archive_LeaveBalances @BatchId = @BatchId;

    SELECT
        ArchiveRunId, ArchiveBatchId, EntityName, StartTime, EndTime,
        Status, RowsArchived, RetentionDays, ErrorMessage
    FROM dbo.ArchiveRunLog
    WHERE ArchiveBatchId = @BatchId
    ORDER BY ArchiveRunId;
END
GO

/* -------------------- Restore procedures -------------------- */

CREATE OR ALTER PROCEDURE dbo.sp_Restore_LeaveRequests
    @ArchiveBatchId UNIQUEIDENTIFIER = NULL,
    @LeaveRequestId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ArchiveBatchId IS NULL AND @LeaveRequestId IS NULL
        THROW 50010, N'Provide @ArchiveBatchId and/or @LeaveRequestId.', 1;

    BEGIN TRY
        BEGIN TRAN;

        SET IDENTITY_INSERT dbo.LeaveRequests ON;

        INSERT INTO dbo.LeaveRequests (
            LeaveRequestId, EmployeeId, LeaveTypeId, StartDate, EndDate, Reason,
            Status, ApprovedBy, ApprovedDate, Remarks, IsCancelled, CreatedDate, ModifiedDate)
        SELECT
            a.LeaveRequestId, a.EmployeeId, a.LeaveTypeId, a.StartDate, a.EndDate, a.Reason,
            a.Status, a.ApprovedBy, a.ApprovedDate, a.Remarks, a.IsCancelled, a.CreatedDate, a.ModifiedDate
        FROM dbo.LeaveRequestsArchive a
        WHERE (@ArchiveBatchId IS NULL OR a.ArchiveBatchId = @ArchiveBatchId)
          AND (@LeaveRequestId IS NULL OR a.LeaveRequestId = @LeaveRequestId)
          AND NOT EXISTS (
              SELECT 1 FROM dbo.LeaveRequests lr WHERE lr.LeaveRequestId = a.LeaveRequestId);

        DECLARE @Rows INT = @@ROWCOUNT;
        SET IDENTITY_INSERT dbo.LeaveRequests OFF;

        DELETE a
        FROM dbo.LeaveRequestsArchive a
        WHERE (@ArchiveBatchId IS NULL OR a.ArchiveBatchId = @ArchiveBatchId)
          AND (@LeaveRequestId IS NULL OR a.LeaveRequestId = @LeaveRequestId)
          AND EXISTS (
              SELECT 1 FROM dbo.LeaveRequests lr WHERE lr.LeaveRequestId = a.LeaveRequestId);

        COMMIT TRAN;
        SELECT @Rows AS RowsRestored, N'Success' AS Status;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        BEGIN TRY SET IDENTITY_INSERT dbo.LeaveRequests OFF; END TRY BEGIN CATCH END CATCH;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Restore_Notifications
    @ArchiveBatchId UNIQUEIDENTIFIER = NULL,
    @NotificationId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ArchiveBatchId IS NULL AND @NotificationId IS NULL
        THROW 50011, N'Provide @ArchiveBatchId and/or @NotificationId.', 1;

    BEGIN TRY
        BEGIN TRAN;
        SET IDENTITY_INSERT dbo.Notifications ON;

        INSERT INTO dbo.Notifications (
            NotificationId, EmployeeId, Title, MessageBody, NotificationType, IsRead, CreatedAt)
        SELECT
            a.NotificationId, a.EmployeeId, a.Title, a.MessageBody, a.NotificationType, a.IsRead, a.CreatedAt
        FROM dbo.NotificationsArchive a
        WHERE (@ArchiveBatchId IS NULL OR a.ArchiveBatchId = @ArchiveBatchId)
          AND (@NotificationId IS NULL OR a.NotificationId = @NotificationId)
          AND NOT EXISTS (
              SELECT 1 FROM dbo.Notifications n WHERE n.NotificationId = a.NotificationId);

        DECLARE @Rows INT = @@ROWCOUNT;
        SET IDENTITY_INSERT dbo.Notifications OFF;

        DELETE a
        FROM dbo.NotificationsArchive a
        WHERE (@ArchiveBatchId IS NULL OR a.ArchiveBatchId = @ArchiveBatchId)
          AND (@NotificationId IS NULL OR a.NotificationId = @NotificationId)
          AND EXISTS (
              SELECT 1 FROM dbo.Notifications n WHERE n.NotificationId = a.NotificationId);

        COMMIT TRAN;
        SELECT @Rows AS RowsRestored, N'Success' AS Status;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        BEGIN TRY SET IDENTITY_INSERT dbo.Notifications OFF; END TRY BEGIN CATCH END CATCH;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Restore_AuditLogs
    @ArchiveBatchId UNIQUEIDENTIFIER = NULL,
    @AuditId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ArchiveBatchId IS NULL AND @AuditId IS NULL
        THROW 50012, N'Provide @ArchiveBatchId and/or @AuditId.', 1;

    BEGIN TRY
        BEGIN TRAN;
        SET IDENTITY_INSERT dbo.AuditLogs ON;

        INSERT INTO dbo.AuditLogs (
            AuditId, TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy, ChangedOn)
        SELECT
            a.AuditId, a.TableName, a.RecordId, a.ActionType, a.OldValue, a.NewValue, a.ChangedBy, a.ChangedOn
        FROM dbo.AuditLogsArchive a
        WHERE (@ArchiveBatchId IS NULL OR a.ArchiveBatchId = @ArchiveBatchId)
          AND (@AuditId IS NULL OR a.AuditId = @AuditId)
          AND NOT EXISTS (
              SELECT 1 FROM dbo.AuditLogs x WHERE x.AuditId = a.AuditId);

        DECLARE @Rows INT = @@ROWCOUNT;
        SET IDENTITY_INSERT dbo.AuditLogs OFF;

        DELETE a
        FROM dbo.AuditLogsArchive a
        WHERE (@ArchiveBatchId IS NULL OR a.ArchiveBatchId = @ArchiveBatchId)
          AND (@AuditId IS NULL OR a.AuditId = @AuditId)
          AND EXISTS (
              SELECT 1 FROM dbo.AuditLogs x WHERE x.AuditId = a.AuditId);

        COMMIT TRAN;
        SELECT @Rows AS RowsRestored, N'Success' AS Status;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        BEGIN TRY SET IDENTITY_INSERT dbo.AuditLogs OFF; END TRY BEGIN CATCH END CATCH;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Restore_LeaveBalances
    @ArchiveBatchId UNIQUEIDENTIFIER = NULL,
    @LeaveBalanceId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ArchiveBatchId IS NULL AND @LeaveBalanceId IS NULL
        THROW 50013, N'Provide @ArchiveBatchId and/or @LeaveBalanceId.', 1;

    BEGIN TRY
        BEGIN TRAN;
        SET IDENTITY_INSERT dbo.LeaveBalances ON;

        INSERT INTO dbo.LeaveBalances (
            LeaveBalanceId, EmployeeId, LeaveTypeId, BalanceYear, EntitledDays,
            UsedDays, IsHistorical, CreatedAt, ClosedAt)
        SELECT
            a.LeaveBalanceId, a.EmployeeId, a.LeaveTypeId, a.BalanceYear, a.EntitledDays,
            a.UsedDays, a.IsHistorical, a.CreatedAt, a.ClosedAt
        FROM dbo.LeaveBalancesArchive a
        WHERE (@ArchiveBatchId IS NULL OR a.ArchiveBatchId = @ArchiveBatchId)
          AND (@LeaveBalanceId IS NULL OR a.LeaveBalanceId = @LeaveBalanceId)
          AND NOT EXISTS (
              SELECT 1 FROM dbo.LeaveBalances b WHERE b.LeaveBalanceId = a.LeaveBalanceId);

        DECLARE @Rows INT = @@ROWCOUNT;
        SET IDENTITY_INSERT dbo.LeaveBalances OFF;

        DELETE a
        FROM dbo.LeaveBalancesArchive a
        WHERE (@ArchiveBatchId IS NULL OR a.ArchiveBatchId = @ArchiveBatchId)
          AND (@LeaveBalanceId IS NULL OR a.LeaveBalanceId = @LeaveBalanceId)
          AND EXISTS (
              SELECT 1 FROM dbo.LeaveBalances b WHERE b.LeaveBalanceId = a.LeaveBalanceId);

        COMMIT TRAN;
        SELECT @Rows AS RowsRestored, N'Success' AS Status;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        BEGIN TRY SET IDENTITY_INSERT dbo.LeaveBalances OFF; END TRY BEGIN CATCH END CATCH;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Archive_GetStatistics
AS
BEGIN
    SET NOCOUNT ON;

    SELECT N'LeaveRequests' AS EntityName,
           (SELECT COUNT(*) FROM dbo.LeaveRequests) AS LiveRows,
           (SELECT COUNT(*) FROM dbo.LeaveRequestsArchive) AS ArchivedRows
    UNION ALL
    SELECT N'Notifications',
           (SELECT COUNT(*) FROM dbo.Notifications),
           (SELECT COUNT(*) FROM dbo.NotificationsArchive)
    UNION ALL
    SELECT N'AuditLogs',
           (SELECT COUNT(*) FROM dbo.AuditLogs),
           (SELECT COUNT(*) FROM dbo.AuditLogsArchive)
    UNION ALL
    SELECT N'LeaveBalances',
           (SELECT COUNT(*) FROM dbo.LeaveBalances),
           (SELECT COUNT(*) FROM dbo.LeaveBalancesArchive);

    SELECT TOP (50)
        ArchiveRunId, ArchiveBatchId, EntityName, StartTime, EndTime,
        Status, RowsArchived, RetentionDays, ErrorMessage
    FROM dbo.ArchiveRunLog
    ORDER BY ArchiveRunId DESC;
END
GO

PRINT '02_Archive_Procedures.sql completed.';
GO
