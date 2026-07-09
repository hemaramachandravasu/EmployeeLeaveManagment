/*
  SECURITY_DEPLOY.sql
  -------------------
  Advanced database security for EmployeeLeaveDb.
  Run AFTER MASTER_DEPLOY.sql on the target SQL Server instance.

  Example:
    sqlcmd -S localhost -E -C -d EmployeeLeaveDb -i Scripts\Security\SECURITY_DEPLOY.sql

  Implements:
  - Dynamic Data Masking (DDM) on sensitive columns
  - Row-Level Security (RLS) aligned with Admin / Manager / Employee roles
  - Database roles: db_elm_ReadOnly, db_elm_ReportViewer, db_elm_DataEntry, db_elm_Admin
  - SQL logins for least-privilege testing (optional dev passwords)
  - sp_DatabaseHealthCheck monitoring procedure
*/

USE EmployeeLeaveDb;
GO

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

/* ===========================
   0) SCHEMA & LINK USERS TO EMPLOYEES
   =========================== */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'security')
    EXEC(N'CREATE SCHEMA security AUTHORIZATION dbo;');
GO

IF COL_LENGTH(N'dbo.Users', N'EmployeeId') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD EmployeeId INT NULL;
    ALTER TABLE dbo.Users ADD CONSTRAINT FK_Users_Employee
        FOREIGN KEY (EmployeeId) REFERENCES dbo.Employees(EmployeeId);
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleName = N'Employee')
    INSERT INTO dbo.Roles (RoleName, Description) VALUES (N'Employee', N'Standard employee with self-service access');
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleName = N'Manager')
    INSERT INTO dbo.Roles (RoleName, Description) VALUES (N'Manager', N'Department manager with team visibility');
GO

-- Dev credentials (all use password: Admin@123) — rotate in production
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserName = N'manager')
    INSERT INTO dbo.Users (UserName, PasswordHash, Email, RoleId, EmployeeId)
    SELECT N'manager',
           N'100000.sVmZ2ZK8pGxLpN3YzQ8wFg==.NIyIfjMBgb7RfEaZ7gSu+7aB0pHL43cs/z1+iyXRoKY=',
           N'manager@company.com',
           r.RoleId,
           1
    FROM dbo.Roles r WHERE r.RoleName = N'Manager';

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserName = N'employee')
    INSERT INTO dbo.Users (UserName, PasswordHash, Email, RoleId, EmployeeId)
    SELECT N'employee',
           N'100000.sVmZ2ZK8pGxLpN3YzQ8wFg==.NIyIfjMBgb7RfEaZ7gSu+7aB0pHL43cs/z1+iyXRoKY=',
           N'employee@company.com',
           r.RoleId,
           2
    FROM dbo.Roles r WHERE r.RoleName = N'Employee';
GO

UPDATE u SET EmployeeId = 1
FROM dbo.Users u
INNER JOIN dbo.Roles r ON r.RoleId = u.RoleId
WHERE u.UserName = N'admin' AND u.EmployeeId IS NULL;
GO

/* ===========================
   1) DROP EXISTING RLS / SECURITY POLICIES
   =========================== */
IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = N'LeaveRequests_RLS')
    DROP SECURITY POLICY security.LeaveRequests_RLS;
IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = N'Employees_RLS')
    DROP SECURITY POLICY security.Employees_RLS;
GO

IF OBJECT_ID(N'security.fn_LeaveRequestAccessPredicate', N'IF') IS NOT NULL
    DROP FUNCTION security.fn_LeaveRequestAccessPredicate;
IF OBJECT_ID(N'security.fn_EmployeeAccessPredicate', N'IF') IS NOT NULL
    DROP FUNCTION security.fn_EmployeeAccessPredicate;
GO

/* ===========================
   2) DYNAMIC DATA MASKING
   =========================== */
-- Employees: contact & personal identifiers
ALTER TABLE dbo.Employees ALTER COLUMN Email NVARCHAR(320) MASKED WITH (FUNCTION = 'email()');
ALTER TABLE dbo.Employees ALTER COLUMN MobileNumber NVARCHAR(20) MASKED WITH (FUNCTION = 'partial(1,"XXX-XXX-",4)');
ALTER TABLE dbo.Employees ALTER COLUMN DateOfBirth DATE MASKED WITH (FUNCTION = 'default()');
ALTER TABLE dbo.Employees ALTER COLUMN Salary DECIMAL(18,2) MASKED WITH (FUNCTION = 'default()');
ALTER TABLE dbo.Employees ALTER COLUMN Address NVARCHAR(500) MASKED WITH (FUNCTION = 'partial(2,"XXXX",2)');
ALTER TABLE dbo.Employees ALTER COLUMN EmployeeCode NVARCHAR(50) MASKED WITH (FUNCTION = 'partial(2,"XX",2)');

-- Users: credentials
ALTER TABLE dbo.Users ALTER COLUMN PasswordHash NVARCHAR(500) MASKED WITH (FUNCTION = 'default()');
ALTER TABLE dbo.Users ALTER COLUMN Email NVARCHAR(320) MASKED WITH (FUNCTION = 'email()');
GO

/* ===========================
   3) ROW-LEVEL SECURITY PREDICATES
   Session context keys set by API: RoleName, EmployeeId, DepartmentId
   =========================== */
CREATE FUNCTION security.fn_LeaveRequestAccessPredicate(@EmployeeId INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS fn_securitypredicate_result
    WHERE
        CAST(SESSION_CONTEXT(N'RoleName') AS NVARCHAR(50)) = N'Admin'
        OR (
            CAST(SESSION_CONTEXT(N'RoleName') AS NVARCHAR(50)) = N'Employee'
            AND @EmployeeId = TRY_CAST(SESSION_CONTEXT(N'EmployeeId') AS INT)
        )
        OR (
            CAST(SESSION_CONTEXT(N'RoleName') AS NVARCHAR(50)) = N'Manager'
            AND EXISTS (
                SELECT 1
                FROM dbo.Employees e
                WHERE e.EmployeeId = @EmployeeId
                  AND e.DepartmentId = TRY_CAST(SESSION_CONTEXT(N'DepartmentId') AS INT)
            )
        );
GO

CREATE FUNCTION security.fn_EmployeeAccessPredicate(@EmployeeId INT, @DepartmentId INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS fn_securitypredicate_result
    WHERE
        CAST(SESSION_CONTEXT(N'RoleName') AS NVARCHAR(50)) = N'Admin'
        OR (
            CAST(SESSION_CONTEXT(N'RoleName') AS NVARCHAR(50)) = N'Employee'
            AND @EmployeeId = TRY_CAST(SESSION_CONTEXT(N'EmployeeId') AS INT)
        )
        OR (
            CAST(SESSION_CONTEXT(N'RoleName') AS NVARCHAR(50)) = N'Manager'
            AND @DepartmentId = TRY_CAST(SESSION_CONTEXT(N'DepartmentId') AS INT)
        );
GO

CREATE SECURITY POLICY security.LeaveRequests_RLS
    ADD FILTER PREDICATE security.fn_LeaveRequestAccessPredicate(EmployeeId) ON dbo.LeaveRequests,
    ADD BLOCK PREDICATE security.fn_LeaveRequestAccessPredicate(EmployeeId) ON dbo.LeaveRequests
    WITH (STATE = ON, SCHEMABINDING = ON);
GO

CREATE SECURITY POLICY security.Employees_RLS
    ADD FILTER PREDICATE security.fn_EmployeeAccessPredicate(EmployeeId, DepartmentId) ON dbo.Employees,
    ADD BLOCK PREDICATE security.fn_EmployeeAccessPredicate(EmployeeId, DepartmentId) ON dbo.Employees
    WITH (STATE = ON, SCHEMABINDING = ON);
GO

/* ===========================
   4) DATABASE ROLES & LEAST PRIVILEGE
   =========================== */
IF DATABASE_PRINCIPAL_ID(N'db_elm_ReadOnly') IS NULL CREATE ROLE db_elm_ReadOnly;
IF DATABASE_PRINCIPAL_ID(N'db_elm_ReportViewer') IS NULL CREATE ROLE db_elm_ReportViewer;
IF DATABASE_PRINCIPAL_ID(N'db_elm_DataEntry') IS NULL CREATE ROLE db_elm_DataEntry;
IF DATABASE_PRINCIPAL_ID(N'db_elm_Admin') IS NULL CREATE ROLE db_elm_Admin;
GO

-- Revoke broad PUBLIC access to sensitive tables (least privilege)
REVOKE SELECT ON dbo.Employees FROM PUBLIC;
REVOKE SELECT ON dbo.LeaveRequests FROM PUBLIC;
REVOKE SELECT ON dbo.Users FROM PUBLIC;
REVOKE SELECT ON dbo.AuditLogs FROM PUBLIC;
GO

-- ReadOnly: reference data only
GRANT SELECT ON dbo.Departments TO db_elm_ReadOnly;
GRANT SELECT ON dbo.LeaveTypes TO db_elm_ReadOnly;
GRANT EXECUTE ON dbo.sp_GetDashboardData TO db_elm_ReadOnly;
GO

-- ReportViewer: reporting SPs (DDM applies — no UNMASK)
GRANT EXECUTE ON dbo.sp_EmployeeLeaveSummary TO db_elm_ReportViewer;
GRANT EXECUTE ON dbo.sp_MonthlyLeaveUtilization TO db_elm_ReportViewer;
GRANT EXECUTE ON dbo.sp_DepartmentWiseLeaveStatistics TO db_elm_ReportViewer;
GRANT EXECUTE ON dbo.sp_PendingLeaveRequests TO db_elm_ReportViewer;
GRANT EXECUTE ON dbo.sp_GetDepartmentLeaveStats TO db_elm_ReportViewer;
GRANT EXECUTE ON dbo.sp_GetMonthlyLeaveUtilization TO db_elm_ReportViewer;
GRANT EXECUTE ON dbo.sp_LeaveTrendAnalysis TO db_elm_ReportViewer;
GRANT EXECUTE ON dbo.sp_DepartmentComparison TO db_elm_ReportViewer;
GRANT EXECUTE ON dbo.sp_FrequentLeavePattern TO db_elm_ReportViewer;
GRANT EXECUTE ON dbo.sp_ForecastLeaveUtilization TO db_elm_ReportViewer;
GO

-- DataEntry: transactional SPs
GRANT EXECUTE ON dbo.sp_AddEmployee TO db_elm_DataEntry;
GRANT EXECUTE ON dbo.sp_UpdateEmployee TO db_elm_DataEntry;
GRANT EXECUTE ON dbo.sp_DeleteEmployee TO db_elm_DataEntry;
GRANT EXECUTE ON dbo.sp_ApplyLeave TO db_elm_DataEntry;
GRANT EXECUTE ON dbo.sp_UpdateLeave TO db_elm_DataEntry;
GRANT EXECUTE ON dbo.sp_CancelLeave TO db_elm_DataEntry;
GRANT EXECUTE ON dbo.sp_ApproveLeave TO db_elm_DataEntry;
GRANT EXECUTE ON dbo.sp_RejectLeave TO db_elm_DataEntry;
GRANT EXECUTE ON dbo.sp_GetAllLeaveRequests TO db_elm_DataEntry;
GRANT EXECUTE ON dbo.sp_GetLeaveById TO db_elm_DataEntry;
GRANT EXECUTE ON dbo.sp_GetLeaveHistory TO db_elm_DataEntry;
GRANT EXECUTE ON dbo.sp_GetPendingLeaveRequests TO db_elm_DataEntry;
GRANT EXECUTE ON dbo.sp_GetLeavesByDateRange TO db_elm_DataEntry;
GO

-- Admin: full SP access + UNMASK + health check
GRANT EXECUTE ON SCHEMA::dbo TO db_elm_Admin;
GRANT UNMASK TO db_elm_Admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO db_elm_Admin;
GO

/* ===========================
   5) SQL LOGINS / USERS (dev only — change passwords in production)
   =========================== */
IF SUSER_ID(N'elm_ReportViewer') IS NULL
    CREATE LOGIN elm_ReportViewer WITH PASSWORD = 'Elm_ReportViewer_Dev1!', CHECK_POLICY = OFF;
IF SUSER_ID(N'elm_DataEntry') IS NULL
    CREATE LOGIN elm_DataEntry WITH PASSWORD = 'Elm_DataEntry_Dev1!', CHECK_POLICY = OFF;
IF SUSER_ID(N'elm_Admin') IS NULL
    CREATE LOGIN elm_Admin WITH PASSWORD = 'Elm_Admin_Dev1!', CHECK_POLICY = OFF;
GO

IF DATABASE_PRINCIPAL_ID(N'elm_ReportViewer') IS NULL
BEGIN
    CREATE USER elm_ReportViewer FOR LOGIN elm_ReportViewer;
    ALTER ROLE db_elm_ReportViewer ADD MEMBER elm_ReportViewer;
END
IF DATABASE_PRINCIPAL_ID(N'elm_DataEntry') IS NULL
BEGIN
    CREATE USER elm_DataEntry FOR LOGIN elm_DataEntry;
    ALTER ROLE db_elm_DataEntry ADD MEMBER elm_DataEntry;
END
IF DATABASE_PRINCIPAL_ID(N'elm_Admin') IS NULL
BEGIN
    CREATE USER elm_Admin FOR LOGIN elm_Admin;
    ALTER ROLE db_elm_Admin ADD MEMBER elm_Admin;
END
GO

/* ===========================
   6) DATABASE HEALTH MONITORING
   =========================== */
CREATE OR ALTER PROCEDURE dbo.sp_DatabaseHealthCheck
AS
BEGIN
    SET NOCOUNT ON;

    -- Table sizes and row counts
    SELECT
        t.name AS TableName,
        SUM(p.rows) AS RowCounts,
        CAST(SUM(a.total_pages) * 8.0 / 1024 AS DECIMAL(18,2)) AS TotalSpaceMB
    FROM sys.tables t
    INNER JOIN sys.indexes i ON t.object_id = i.object_id
    INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
    INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
    WHERE t.is_ms_shipped = 0 AND i.index_id <= 1
    GROUP BY t.name
    ORDER BY TotalSpaceMB DESC;

    -- Index fragmentation (actionable levels)
    SELECT TOP (25)
        OBJECT_NAME(ips.object_id) AS TableName,
        i.name AS IndexName,
        ips.index_type_desc AS IndexType,
        ips.avg_fragmentation_in_percent AS FragmentationPercent,
        ips.page_count AS PageCount
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, N'LIMITED') ips
    INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE ips.page_count > 100
    ORDER BY ips.avg_fragmentation_in_percent DESC;

    -- Currently long-running requests
    SELECT TOP (20)
        r.session_id AS SessionId,
        r.status,
        r.command,
        DB_NAME(r.database_id) AS DatabaseName,
        r.total_elapsed_time / 1000 AS ElapsedMs,
        SUBSTRING(t.text, (r.statement_start_offset / 2) + 1,
            ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(t.text)
              ELSE r.statement_end_offset END - r.statement_start_offset) / 2) + 1) AS RunningQuery
    FROM sys.dm_exec_requests r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
    WHERE r.database_id = DB_ID()
      AND r.session_id <> @@SPID
    ORDER BY r.total_elapsed_time DESC;

    -- Security posture summary
    SELECT
        (SELECT COUNT(*) FROM sys.masked_columns mc
         INNER JOIN sys.columns c ON mc.object_id = c.object_id AND mc.column_id = c.column_id) AS MaskedColumnCount,
        (SELECT COUNT(*) FROM sys.security_policies) AS ActiveSecurityPolicyCount,
        (SELECT COUNT(*) FROM sys.database_principals WHERE type = 'R' AND name LIKE N'db_elm_%') AS ElmDatabaseRoleCount;
END
GO

GRANT EXECUTE ON dbo.sp_DatabaseHealthCheck TO db_elm_ReportViewer, db_elm_Admin;
GO

PRINT 'SECURITY_DEPLOY.sql completed successfully.';
GO
