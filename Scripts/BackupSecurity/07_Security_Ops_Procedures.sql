/*
  Security Operations Extension
  Complements Scripts/Security/SECURITY_DEPLOY.sql (DDM, RLS, roles, logins).
  Adds login/user inventory helpers and privileged role review.
*/
USE EmployeeLeaveDb;
GO

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Security_ListDatabaseRoles
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        r.name AS RoleName,
        m.name AS MemberName,
        m.type_desc AS MemberType
    FROM sys.database_role_members rm
    INNER JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
    INNER JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
    WHERE r.name LIKE N'db_elm_%'
    ORDER BY r.name, m.name;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Security_ListUsersAndLogins
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        dp.name AS DatabaseUser,
        dp.type_desc AS UserType,
        dp.authentication_type_desc AS AuthType,
        dp.create_date AS CreatedAt,
        sp.name AS ServerLogin,
        sp.type_desc AS LoginType,
        sp.is_disabled AS LoginDisabled
    FROM sys.database_principals dp
    LEFT JOIN sys.server_principals sp ON sp.sid = dp.sid
    WHERE dp.type IN ('S', 'U', 'G')
      AND dp.name NOT IN (N'dbo', N'guest', N'INFORMATION_SCHEMA', N'sys')
    ORDER BY dp.name;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Security_GrantLeastPrivilegePreset
    @DatabaseUser SYSNAME,
    @Preset NVARCHAR(30)   -- ReadOnly / ReportViewer / DataEntry / Admin
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @DatabaseUser)
        THROW 53001, N'Database user does not exist.', 1;

    DECLARE @Role SYSNAME =
        CASE @Preset
            WHEN N'ReadOnly' THEN N'db_elm_ReadOnly'
            WHEN N'ReportViewer' THEN N'db_elm_ReportViewer'
            WHEN N'DataEntry' THEN N'db_elm_DataEntry'
            WHEN N'Admin' THEN N'db_elm_Admin'
            ELSE NULL
        END;

    IF @Role IS NULL
        THROW 53002, N'Unknown preset. Use ReadOnly, ReportViewer, DataEntry, or Admin.', 1;

    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @Role AND type = 'R')
        THROW 53003, N'Target role missing. Deploy Scripts/Security/SECURITY_DEPLOY.sql first.', 1;

    DECLARE @Sql NVARCHAR(400) =
        N'ALTER ROLE ' + QUOTENAME(@Role) + N' ADD MEMBER ' + QUOTENAME(@DatabaseUser) + N';';
    EXEC (@Sql);

    SELECT @DatabaseUser AS DatabaseUser, @Role AS GrantedRole, N'Success' AS Status;
END
GO

PRINT 'Security ops procedures created. Run SECURITY_DEPLOY.sql for DDM/RLS/roles.';
GO
