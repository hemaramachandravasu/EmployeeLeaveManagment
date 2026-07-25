/*
  Task 3: Users audit trigger (password hash redacted).
  sqlcmd -S localhost -E -C -i Scripts\Database\Task3_Users_Audit_Trigger.sql
*/
USE EmployeeLeaveDb;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID(N'dbo.trg_Users_Audit', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Users_Audit;
GO

CREATE TRIGGER dbo.trg_Users_Audit
ON dbo.Users
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditLogs (TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy)
    SELECT
        N'Users',
        COALESCE(i.UserId, d.UserId),
        CASE
            WHEN i.UserId IS NOT NULL AND d.UserId IS NULL THEN N'Insert'
            WHEN i.UserId IS NOT NULL AND d.UserId IS NOT NULL THEN N'Update'
            ELSE N'Delete'
        END,
        CASE
            WHEN d.UserId IS NULL THEN NULL
            ELSE (
                SELECT
                    d.UserId,
                    d.UserName,
                    N'***' AS PasswordHash,
                    d.Email,
                    d.RoleId,
                    d.EmployeeId,
                    d.IsActive,
                    d.CreatedDate,
                    d.ModifiedDate
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        END,
        CASE
            WHEN i.UserId IS NULL THEN NULL
            ELSE (
                SELECT
                    i.UserId,
                    i.UserName,
                    N'***' AS PasswordHash,
                    i.Email,
                    i.RoleId,
                    i.EmployeeId,
                    i.IsActive,
                    i.CreatedDate,
                    i.ModifiedDate
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        END,
        CONCAT(SUSER_SNAME(), N' | ', APP_NAME())
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.UserId = d.UserId;
END
GO
