/*
================================================================================
  Extended Database Auditing — Critical Tables + User Activity
  Database: EmployeeLeaveDb

  Extends existing AuditLogs coverage (Employees, LeaveRequests) to:
    Users, Departments, LeaveTypes, Roles, LeaveBalances, Holidays, LeavePolicies
================================================================================
*/
USE EmployeeLeaveDb;
GO

/* ---------- Helper: write AuditLogs row from JSON payloads ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Audit_Write
    @TableName  NVARCHAR(128),
    @RecordId   INT,
    @ActionType NVARCHAR(20),
    @OldValue   NVARCHAR(MAX) = NULL,
    @NewValue   NVARCHAR(MAX) = NULL,
    @ChangedBy  NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLogs (TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy)
    VALUES (
        @TableName,
        @RecordId,
        @ActionType,
        @OldValue,
        @NewValue,
        ISNULL(@ChangedBy, CONCAT(SUSER_SNAME(), N' | ', APP_NAME()))
    );
END
GO

/* ---------- User activity logger ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Audit_LogUserActivity
    @UserId         INT = NULL,
    @UserName       NVARCHAR(100) = NULL,
    @ActivityType   NVARCHAR(50),
    @EntityName     NVARCHAR(128) = NULL,
    @EntityId       INT = NULL,
    @ActivityDetail NVARCHAR(1000) = NULL,
    @IpAddress      NVARCHAR(64) = NULL,
    @Success        BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.UserActivityLog
        (UserId, UserName, ActivityType, EntityName, EntityId, ActivityDetail, IpAddress, Success)
    VALUES
        (@UserId, @UserName, @ActivityType, @EntityName, @EntityId, @ActivityDetail, @IpAddress, @Success);

    SELECT SCOPE_IDENTITY() AS ActivityId;
END
GO

/* ---------- Exception logger ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_Audit_LogException
    @SourceProc    NVARCHAR(256) = NULL,
    @ErrorNumber   INT = NULL,
    @ErrorSeverity INT = NULL,
    @ErrorState    INT = NULL,
    @ErrorMessage  NVARCHAR(4000),
    @ContextInfo   NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.DatabaseExceptionLog
        (SourceProc, ErrorNumber, ErrorSeverity, ErrorState, ErrorMessage, ContextInfo)
    VALUES
        (@SourceProc, @ErrorNumber, @ErrorSeverity, @ErrorState, @ErrorMessage, @ContextInfo);
END
GO

/* ===================== TRIGGERS ===================== */

/* Users */
IF OBJECT_ID(N'dbo.trg_Users_Audit', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_Users_Audit;
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
        CASE WHEN d.UserId IS NULL THEN NULL
             ELSE (SELECT d.UserId, d.UserName, d.Email, d.RoleId, d.EmployeeId, d.IsActive, d.CreatedDate, d.ModifiedDate
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.UserId IS NULL THEN NULL
             ELSE (SELECT i.UserId, i.UserName, i.Email, i.RoleId, i.EmployeeId, i.IsActive, i.CreatedDate, i.ModifiedDate
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CONCAT(SUSER_SNAME(), N' | ', APP_NAME())
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.UserId = d.UserId;
END
GO

/* Departments */
IF OBJECT_ID(N'dbo.trg_Departments_Audit', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_Departments_Audit;
GO
CREATE TRIGGER dbo.trg_Departments_Audit
ON dbo.Departments
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLogs (TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy)
    SELECT
        N'Departments',
        COALESCE(i.DepartmentId, d.DepartmentId),
        CASE
            WHEN i.DepartmentId IS NOT NULL AND d.DepartmentId IS NULL THEN N'Insert'
            WHEN i.DepartmentId IS NOT NULL AND d.DepartmentId IS NOT NULL THEN N'Update'
            ELSE N'Delete'
        END,
        CASE WHEN d.DepartmentId IS NULL THEN NULL ELSE (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.DepartmentId IS NULL THEN NULL ELSE (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CONCAT(SUSER_SNAME(), N' | ', APP_NAME())
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.DepartmentId = d.DepartmentId;
END
GO

/* LeaveTypes */
IF OBJECT_ID(N'dbo.trg_LeaveTypes_Audit', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_LeaveTypes_Audit;
GO
CREATE TRIGGER dbo.trg_LeaveTypes_Audit
ON dbo.LeaveTypes
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLogs (TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy)
    SELECT
        N'LeaveTypes',
        COALESCE(i.LeaveTypeId, d.LeaveTypeId),
        CASE
            WHEN i.LeaveTypeId IS NOT NULL AND d.LeaveTypeId IS NULL THEN N'Insert'
            WHEN i.LeaveTypeId IS NOT NULL AND d.LeaveTypeId IS NOT NULL THEN N'Update'
            ELSE N'Delete'
        END,
        CASE WHEN d.LeaveTypeId IS NULL THEN NULL ELSE (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.LeaveTypeId IS NULL THEN NULL ELSE (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CONCAT(SUSER_SNAME(), N' | ', APP_NAME())
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.LeaveTypeId = d.LeaveTypeId;
END
GO

/* Roles */
IF OBJECT_ID(N'dbo.trg_Roles_Audit', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_Roles_Audit;
GO
CREATE TRIGGER dbo.trg_Roles_Audit
ON dbo.Roles
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLogs (TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy)
    SELECT
        N'Roles',
        COALESCE(i.RoleId, d.RoleId),
        CASE
            WHEN i.RoleId IS NOT NULL AND d.RoleId IS NULL THEN N'Insert'
            WHEN i.RoleId IS NOT NULL AND d.RoleId IS NOT NULL THEN N'Update'
            ELSE N'Delete'
        END,
        CASE WHEN d.RoleId IS NULL THEN NULL ELSE (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.RoleId IS NULL THEN NULL ELSE (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CONCAT(SUSER_SNAME(), N' | ', APP_NAME())
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.RoleId = d.RoleId;
END
GO

/* LeaveBalances (if present) */
IF OBJECT_ID(N'dbo.LeaveBalances', N'U') IS NOT NULL
BEGIN
    IF OBJECT_ID(N'dbo.trg_LeaveBalances_Audit', N'TR') IS NOT NULL
        DROP TRIGGER dbo.trg_LeaveBalances_Audit;

    EXEC(N'
CREATE TRIGGER dbo.trg_LeaveBalances_Audit
ON dbo.LeaveBalances
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLogs (TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy)
    SELECT
        N''LeaveBalances'',
        COALESCE(i.LeaveBalanceId, d.LeaveBalanceId),
        CASE
            WHEN i.LeaveBalanceId IS NOT NULL AND d.LeaveBalanceId IS NULL THEN N''Insert''
            WHEN i.LeaveBalanceId IS NOT NULL AND d.LeaveBalanceId IS NOT NULL THEN N''Update''
            ELSE N''Delete''
        END,
        CASE WHEN d.LeaveBalanceId IS NULL THEN NULL ELSE (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.LeaveBalanceId IS NULL THEN NULL ELSE (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CONCAT(SUSER_SNAME(), N'' | '', APP_NAME())
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.LeaveBalanceId = d.LeaveBalanceId;
END');
END
GO

/* Holidays */
IF OBJECT_ID(N'dbo.trg_Holidays_Audit', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_Holidays_Audit;
GO
CREATE TRIGGER dbo.trg_Holidays_Audit
ON dbo.Holidays
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLogs (TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy)
    SELECT
        N'Holidays',
        COALESCE(i.HolidayId, d.HolidayId),
        CASE
            WHEN i.HolidayId IS NOT NULL AND d.HolidayId IS NULL THEN N'Insert'
            WHEN i.HolidayId IS NOT NULL AND d.HolidayId IS NOT NULL THEN N'Update'
            ELSE N'Delete'
        END,
        CASE WHEN d.HolidayId IS NULL THEN NULL ELSE (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.HolidayId IS NULL THEN NULL ELSE (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CONCAT(SUSER_SNAME(), N' | ', APP_NAME())
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.HolidayId = d.HolidayId;
END
GO

/* LeavePolicies */
IF OBJECT_ID(N'dbo.trg_LeavePolicies_Audit', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_LeavePolicies_Audit;
GO
CREATE TRIGGER dbo.trg_LeavePolicies_Audit
ON dbo.LeavePolicies
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLogs (TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy)
    SELECT
        N'LeavePolicies',
        COALESCE(i.PolicyId, d.PolicyId),
        CASE
            WHEN i.PolicyId IS NOT NULL AND d.PolicyId IS NULL THEN N'Insert'
            WHEN i.PolicyId IS NOT NULL AND d.PolicyId IS NOT NULL THEN N'Update'
            ELSE N'Delete'
        END,
        CASE WHEN d.PolicyId IS NULL THEN NULL ELSE (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.PolicyId IS NULL THEN NULL ELSE (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CONCAT(SUSER_SNAME(), N' | ', APP_NAME())
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.PolicyId = d.PolicyId;
END
GO

/* Ensure Employees + LeaveRequests triggers exist (recreate if missing) */
IF OBJECT_ID(N'dbo.trg_Employees_Audit', N'TR') IS NULL
BEGIN
    EXEC(N'
CREATE TRIGGER dbo.trg_Employees_Audit
ON dbo.Employees
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLogs (TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy)
    SELECT
        N''Employees'',
        COALESCE(i.EmployeeId, d.EmployeeId),
        CASE
            WHEN i.EmployeeId IS NOT NULL AND d.EmployeeId IS NULL THEN N''Insert''
            WHEN i.EmployeeId IS NOT NULL AND d.EmployeeId IS NOT NULL THEN N''Update''
            ELSE N''Delete''
        END,
        CASE WHEN d.EmployeeId IS NULL THEN NULL ELSE (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.EmployeeId IS NULL THEN NULL ELSE (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CONCAT(SUSER_SNAME(), N'' | '', APP_NAME())
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.EmployeeId = d.EmployeeId;
END');
END
GO

IF OBJECT_ID(N'dbo.trg_LeaveRequests_Audit', N'TR') IS NULL
BEGIN
    EXEC(N'
CREATE TRIGGER dbo.trg_LeaveRequests_Audit
ON dbo.LeaveRequests
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLogs (TableName, RecordId, ActionType, OldValue, NewValue, ChangedBy)
    SELECT
        N''LeaveRequests'',
        COALESCE(i.LeaveRequestId, d.LeaveRequestId),
        CASE
            WHEN i.LeaveRequestId IS NOT NULL AND d.LeaveRequestId IS NULL THEN N''Insert''
            WHEN i.LeaveRequestId IS NOT NULL AND d.LeaveRequestId IS NOT NULL THEN N''Update''
            ELSE N''Delete''
        END,
        CASE WHEN d.LeaveRequestId IS NULL THEN NULL ELSE (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.LeaveRequestId IS NULL THEN NULL ELSE (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CONCAT(SUSER_SNAME(), N'' | '', APP_NAME())
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.LeaveRequestId = d.LeaveRequestId;
END');
END
GO

PRINT '02_Auditing_Triggers completed.';
GO
