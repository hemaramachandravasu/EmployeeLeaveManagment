/*
================================================================================
  Database Migration Framework Procedures
  Database: EmployeeLeaveDb

  Apply / rollback controlled schema changes with history tracking.
  UpSql/DownSql are executed via dynamic SQL inside a transaction.
================================================================================
*/
USE EmployeeLeaveDb;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Mig_LogRunStart
    @ActionType NVARCHAR(20),
    @VersionNumber NVARCHAR(32) = NULL,
    @RunId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.SchemaMigrationRunLog (ActionType, VersionNumber, Status)
    VALUES (@ActionType, @VersionNumber, N'Running');
    SET @RunId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Mig_LogRunEnd
    @RunId INT,
    @Status NVARCHAR(20),
    @Details NVARCHAR(MAX) = NULL,
    @ErrorMessage NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.SchemaMigrationRunLog
    SET EndTime = SYSUTCDATETIME(), Status = @Status, Details = @Details, ErrorMessage = @ErrorMessage
    WHERE RunId = @RunId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Mig_Register
    @VersionNumber NVARCHAR(32),
    @MigrationName NVARCHAR(200),
    @ScriptName NVARCHAR(260) = NULL,
    @UpSql NVARCHAR(MAX),
    @DownSql NVARCHAR(MAX) = NULL,
    @Notes NVARCHAR(500) = NULL,
    @ApplyNow BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE VersionNumber = @VersionNumber AND Status = N'Applied')
        THROW 51001, 'Migration version already applied.', 1;

    IF @ApplyNow = 1
    BEGIN
        EXEC dbo.sp_Mig_Apply
            @VersionNumber = @VersionNumber,
            @MigrationName = @MigrationName,
            @ScriptName = @ScriptName,
            @UpSql = @UpSql,
            @DownSql = @DownSql,
            @Notes = @Notes;
        RETURN;
    END

    /* Register only (pending apply via sp_Mig_Apply with same version if previously failed) */
    IF EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE VersionNumber = @VersionNumber)
    BEGIN
        UPDATE dbo.SchemaMigrationHistory
        SET MigrationName = @MigrationName,
            ScriptName = @ScriptName,
            UpSql = @UpSql,
            DownSql = @DownSql,
            Notes = @Notes,
            Status = N'Pending',
            ErrorMessage = NULL
        WHERE VersionNumber = @VersionNumber;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.SchemaMigrationHistory
            (VersionNumber, MigrationName, ScriptName, UpSql, DownSql, Status, Notes, AppliedAt)
        VALUES
            (@VersionNumber, @MigrationName, @ScriptName, @UpSql, @DownSql, N'Pending', @Notes, SYSUTCDATETIME());
    END

    SELECT * FROM dbo.SchemaMigrationHistory WHERE VersionNumber = @VersionNumber;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Mig_Apply
    @VersionNumber NVARCHAR(32),
    @MigrationName NVARCHAR(200) = NULL,
    @ScriptName NVARCHAR(260) = NULL,
    @UpSql NVARCHAR(MAX) = NULL,
    @DownSql NVARCHAR(MAX) = NULL,
    @Notes NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RunId INT, @Start DATETIME2 = SYSUTCDATETIME(), @Err NVARCHAR(4000), @Details NVARCHAR(500);
    DECLARE @ExistingStatus NVARCHAR(20), @Sql NVARCHAR(MAX), @Down NVARCHAR(MAX), @Name NVARCHAR(200);

    IF EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE VersionNumber = @VersionNumber AND Status = N'Applied')
        THROW 51001, 'Migration version already applied.', 1;

    SELECT
        @ExistingStatus = Status,
        @Sql = ISNULL(@UpSql, UpSql),
        @Down = ISNULL(@DownSql, DownSql),
        @Name = ISNULL(@MigrationName, MigrationName)
    FROM dbo.SchemaMigrationHistory
    WHERE VersionNumber = @VersionNumber;

    IF @Sql IS NULL
        SET @Sql = @UpSql;
    IF @Name IS NULL
        SET @Name = @MigrationName;
    IF @Down IS NULL
        SET @Down = @DownSql;

    IF @Sql IS NULL OR LEN(LTRIM(RTRIM(@Sql))) = 0
        THROW 51002, 'UpSql is required to apply a migration.', 1;
    IF @Name IS NULL OR LEN(LTRIM(RTRIM(@Name))) = 0
        THROW 51003, 'MigrationName is required.', 1;

    EXEC dbo.sp_Mig_LogRunStart N'Apply', @VersionNumber, @RunId OUTPUT;

    BEGIN TRY
        BEGIN TRAN;

        EXEC sys.sp_executesql @Sql;

        IF EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE VersionNumber = @VersionNumber)
        BEGIN
            UPDATE dbo.SchemaMigrationHistory
            SET MigrationName = @Name,
                ScriptName = ISNULL(@ScriptName, ScriptName),
                UpSql = @Sql,
                DownSql = @Down,
                AppliedAt = SYSUTCDATETIME(),
                AppliedBy = SUSER_SNAME(),
                Status = N'Applied',
                DurationMs = DATEDIFF(MILLISECOND, @Start, SYSUTCDATETIME()),
                ErrorMessage = NULL,
                Notes = ISNULL(@Notes, Notes)
            WHERE VersionNumber = @VersionNumber;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.SchemaMigrationHistory
                (VersionNumber, MigrationName, ScriptName, UpSql, DownSql, Status, DurationMs, Notes)
            VALUES
                (@VersionNumber, @Name, @ScriptName, @Sql, @Down, N'Applied',
                 DATEDIFF(MILLISECOND, @Start, SYSUTCDATETIME()), @Notes);
        END

        COMMIT TRAN;

        SET @Details = CONCAT(N'Applied ', @VersionNumber, N' — ', @Name);
        EXEC dbo.sp_Mig_LogRunEnd @RunId, N'Success', @Details;

        SELECT * FROM dbo.SchemaMigrationHistory WHERE VersionNumber = @VersionNumber;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        SET @Err = ERROR_MESSAGE();

        IF EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE VersionNumber = @VersionNumber)
            UPDATE dbo.SchemaMigrationHistory
            SET Status = N'Failed', ErrorMessage = @Err, AppliedAt = SYSUTCDATETIME()
            WHERE VersionNumber = @VersionNumber;
        ELSE
            INSERT INTO dbo.SchemaMigrationHistory
                (VersionNumber, MigrationName, ScriptName, UpSql, DownSql, Status, ErrorMessage, Notes)
            VALUES
                (@VersionNumber, ISNULL(@Name, N'Unknown'), @ScriptName, @Sql, @Down, N'Failed', @Err, @Notes);

        EXEC dbo.sp_Mig_LogRunEnd @RunId, N'Failed', NULL, @Err;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Mig_Rollback
    @VersionNumber NVARCHAR(32) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RunId INT, @Start DATETIME2 = SYSUTCDATETIME(), @Err NVARCHAR(4000), @Details NVARCHAR(500);
    DECLARE @Down NVARCHAR(MAX), @Name NVARCHAR(200), @Ver NVARCHAR(32);

    IF @VersionNumber IS NULL
        SELECT TOP (1)
            @Ver = VersionNumber, @Down = DownSql, @Name = MigrationName
        FROM dbo.SchemaMigrationHistory
        WHERE Status = N'Applied'
          AND VersionNumber <> N'0001.0000'
        ORDER BY AppliedAt DESC, MigrationId DESC;
    ELSE
        SELECT
            @Ver = VersionNumber, @Down = DownSql, @Name = MigrationName
        FROM dbo.SchemaMigrationHistory
        WHERE VersionNumber = @VersionNumber AND Status = N'Applied';

    IF @Ver IS NULL
        THROW 51004, 'No applied migration found to roll back.', 1;
    IF @Ver = N'0001.0000'
        THROW 51005, 'Baseline migration cannot be rolled back.', 1;
    IF @Down IS NULL OR LEN(LTRIM(RTRIM(@Down))) = 0
        THROW 51006, 'DownSql is empty for this migration; cannot roll back.', 1;

    EXEC dbo.sp_Mig_LogRunStart N'Rollback', @Ver, @RunId OUTPUT;

    BEGIN TRY
        BEGIN TRAN;
        EXEC sys.sp_executesql @Down;

        UPDATE dbo.SchemaMigrationHistory
        SET Status = N'RolledBack',
            AppliedAt = SYSUTCDATETIME(),
            AppliedBy = SUSER_SNAME(),
            DurationMs = DATEDIFF(MILLISECOND, @Start, SYSUTCDATETIME()),
            ErrorMessage = NULL
        WHERE VersionNumber = @Ver;

        COMMIT TRAN;

        SET @Details = CONCAT(N'Rolled back ', @Ver, N' — ', @Name);
        EXEC dbo.sp_Mig_LogRunEnd @RunId, N'Success', @Details;

        SELECT * FROM dbo.SchemaMigrationHistory WHERE VersionNumber = @Ver;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        SET @Err = ERROR_MESSAGE();
        UPDATE dbo.SchemaMigrationHistory
        SET ErrorMessage = @Err
        WHERE VersionNumber = @Ver;
        EXEC dbo.sp_Mig_LogRunEnd @RunId, N'Failed', NULL, @Err;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Mig_GetHistory
    @Status NVARCHAR(20) = NULL,
    @TopN INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@TopN)
        MigrationId, VersionNumber, MigrationName, ScriptName, Status,
        AppliedAt, AppliedBy, DurationMs, ErrorMessage, Notes
    FROM dbo.SchemaMigrationHistory
    WHERE (@Status IS NULL OR Status = @Status)
    ORDER BY AppliedAt DESC, MigrationId DESC;
END
GO

/* Sample incremental migration: add optional Meta_SystemSetting table */
CREATE OR ALTER PROCEDURE dbo.sp_Mig_ApplySample_0001_0001
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Up NVARCHAR(MAX) = N'
IF OBJECT_ID(N''dbo.Meta_SystemSetting'', N''U'') IS NULL
BEGIN
    CREATE TABLE dbo.Meta_SystemSetting
    (
        SettingId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        SettingKey NVARCHAR(100) NOT NULL UNIQUE,
        SettingValue NVARCHAR(500) NULL,
        CategoryCode NVARCHAR(50) NULL,
        ModifiedAt DATETIME2 NOT NULL CONSTRAINT DF_MetaSysSetting_Mod DEFAULT (SYSUTCDATETIME())
    );
END
';

    DECLARE @Down NVARCHAR(MAX) = N'
IF OBJECT_ID(N''dbo.Meta_SystemSetting'', N''U'') IS NOT NULL
    DROP TABLE dbo.Meta_SystemSetting;
';

    EXEC dbo.sp_Mig_Apply
        @VersionNumber = N'0001.0001',
        @MigrationName = N'Add Meta_SystemSetting table',
        @ScriptName = N'sp_Mig_ApplySample_0001_0001',
        @UpSql = @Up,
        @DownSql = @Down,
        @Notes = N'Sample incremental migration for framework demo.';
END
GO

PRINT '02_Migration_Procedures completed.';
GO
