/*
================================================================================
  Metadata Management Procedures
  Database: EmployeeLeaveDb
================================================================================
*/
USE EmployeeLeaveDb;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Meta_GetModules
    @ActiveOnly BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ModuleId, ModuleCode, ModuleName, Description, IsActive, SortOrder, CreatedAt
    FROM dbo.Meta_ApplicationModule
    WHERE (@ActiveOnly = 0 OR IsActive = 1)
    ORDER BY SortOrder, ModuleCode;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Meta_GetConfigCategories
    @ModuleCode NVARCHAR(50) = NULL,
    @ActiveOnly BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CategoryId, CategoryCode, CategoryName, ModuleCode, Description, IsActive, CreatedAt
    FROM dbo.Meta_ConfigCategory
    WHERE (@ActiveOnly = 0 OR IsActive = 1)
      AND (@ModuleCode IS NULL OR ModuleCode = @ModuleCode)
    ORDER BY CategoryCode;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Meta_GetLookupValues
    @CategoryCode NVARCHAR(50),
    @ActiveOnly BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT LookupId, CategoryCode, LookupCode, DisplayName, Description, SortOrder, IsActive, ExtraJson, CreatedAt
    FROM dbo.Meta_LookupValue
    WHERE CategoryCode = @CategoryCode
      AND (@ActiveOnly = 0 OR IsActive = 1)
    ORDER BY SortOrder, LookupCode;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Meta_GetAuditCategories
    @ActiveOnly BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT AuditCategoryId, CategoryCode, CategoryName, Description, SeverityDefault, IsActive, CreatedAt
    FROM dbo.Meta_AuditCategory
    WHERE (@ActiveOnly = 0 OR IsActive = 1)
    ORDER BY CategoryCode;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Meta_UpsertLookupValue
    @CategoryCode NVARCHAR(50),
    @LookupCode NVARCHAR(50),
    @DisplayName NVARCHAR(200),
    @Description NVARCHAR(500) = NULL,
    @SortOrder INT = 0,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.Meta_LookupValue WHERE CategoryCode = @CategoryCode AND LookupCode = @LookupCode)
        UPDATE dbo.Meta_LookupValue
        SET DisplayName = @DisplayName,
            Description = @Description,
            SortOrder = @SortOrder,
            IsActive = @IsActive
        WHERE CategoryCode = @CategoryCode AND LookupCode = @LookupCode;
    ELSE
        INSERT INTO dbo.Meta_LookupValue (CategoryCode, LookupCode, DisplayName, Description, SortOrder, IsActive)
        VALUES (@CategoryCode, @LookupCode, @DisplayName, @Description, @SortOrder, @IsActive);

    SELECT * FROM dbo.Meta_LookupValue WHERE CategoryCode = @CategoryCode AND LookupCode = @LookupCode;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Meta_RefreshCatalog
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunId INT;
    EXEC dbo.sp_Mig_LogRunStart N'MetadataRefresh', NULL, @RunId OUTPUT;

    BEGIN TRY
        /* Ensure core leave statuses exist */
        MERGE dbo.Meta_LookupValue AS t
        USING (VALUES
            (N'LEAVE_STATUS', N'Pending', N'Pending', 1),
            (N'LEAVE_STATUS', N'Approved', N'Approved', 2),
            (N'LEAVE_STATUS', N'Rejected', N'Rejected', 3),
            (N'LEAVE_STATUS', N'Cancelled', N'Cancelled', 4)
        ) AS s (CategoryCode, LookupCode, DisplayName, SortOrder)
        ON t.CategoryCode = s.CategoryCode AND t.LookupCode = s.LookupCode
        WHEN NOT MATCHED THEN
            INSERT (CategoryCode, LookupCode, DisplayName, SortOrder, IsActive)
            VALUES (s.CategoryCode, s.LookupCode, s.DisplayName, s.SortOrder, 1);

        /* Sync LeaveTypes into lookups under LEAVE_TYPE */
        INSERT INTO dbo.Meta_LookupValue (CategoryCode, LookupCode, DisplayName, SortOrder, IsActive)
        SELECT N'LEAVE_TYPE', CAST(lt.LeaveTypeId AS NVARCHAR(50)), lt.LeaveTypeName, lt.LeaveTypeId, lt.IsActive
        FROM dbo.LeaveTypes lt
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.Meta_LookupValue v
            WHERE v.CategoryCode = N'LEAVE_TYPE' AND v.LookupCode = CAST(lt.LeaveTypeId AS NVARCHAR(50)));

        DECLARE @Details NVARCHAR(200) = N'Metadata catalog refreshed.';
        EXEC dbo.sp_Mig_LogRunEnd @RunId, N'Success', @Details;

        SELECT
            (SELECT COUNT(*) FROM dbo.Meta_ApplicationModule WHERE IsActive = 1) AS ActiveModules,
            (SELECT COUNT(*) FROM dbo.Meta_ConfigCategory WHERE IsActive = 1) AS ActiveConfigCategories,
            (SELECT COUNT(*) FROM dbo.Meta_LookupValue WHERE IsActive = 1) AS ActiveLookups,
            (SELECT COUNT(*) FROM dbo.Meta_AuditCategory WHERE IsActive = 1) AS ActiveAuditCategories,
            SYSUTCDATETIME() AS RefreshedAtUtc;
    END TRY
    BEGIN CATCH
        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        EXEC dbo.sp_Mig_LogRunEnd @RunId, N'Failed', NULL, @Err;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_MetadataUsage
AS
BEGIN
    SET NOCOUNT ON;

    SELECT N'Module' AS MetaType, ModuleCode AS Code, ModuleName AS Name, IsActive, CreatedAt
    FROM dbo.Meta_ApplicationModule
    UNION ALL
    SELECT N'ConfigCategory', CategoryCode, CategoryName, IsActive, CreatedAt
    FROM dbo.Meta_ConfigCategory
    UNION ALL
    SELECT N'AuditCategory', CategoryCode, CategoryName, IsActive, CreatedAt
    FROM dbo.Meta_AuditCategory
    ORDER BY MetaType, Code;

    SELECT CategoryCode, COUNT(*) AS LookupCount,
           SUM(CASE WHEN IsActive = 1 THEN 1 ELSE 0 END) AS ActiveCount
    FROM dbo.Meta_LookupValue
    GROUP BY CategoryCode
    ORDER BY CategoryCode;
END
GO

PRINT '03_Metadata_Procedures completed.';
GO
