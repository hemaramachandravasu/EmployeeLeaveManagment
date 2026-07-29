/*
================================================================================
  Migration Framework, Metadata & Validation — Schema
  Database: EmployeeLeaveDb
================================================================================
*/
USE EmployeeLeaveDb;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------- Schema migration history ---------- */
IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SchemaMigrationHistory
    (
        MigrationId      INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        VersionNumber    NVARCHAR(32) NOT NULL,
        MigrationName    NVARCHAR(200) NOT NULL,
        ScriptName       NVARCHAR(260) NULL,
        ScriptHash       NVARCHAR(64) NULL,
        UpSql            NVARCHAR(MAX) NULL,
        DownSql          NVARCHAR(MAX) NULL,
        AppliedAt        DATETIME2 NOT NULL CONSTRAINT DF_SchemaMig_Applied DEFAULT (SYSUTCDATETIME()),
        AppliedBy        NVARCHAR(128) NOT NULL CONSTRAINT DF_SchemaMig_By DEFAULT (SUSER_SNAME()),
        Status           NVARCHAR(20) NOT NULL,  -- Applied / RolledBack / Failed
        DurationMs       INT NULL,
        ErrorMessage     NVARCHAR(4000) NULL,
        Notes            NVARCHAR(500) NULL,
        CONSTRAINT UQ_SchemaMigration_Version UNIQUE (VersionNumber)
    );

    CREATE INDEX IX_SchemaMigrationHistory_Status
        ON dbo.SchemaMigrationHistory (Status, AppliedAt DESC);
END
GO

IF OBJECT_ID(N'dbo.SchemaMigrationRunLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SchemaMigrationRunLog
    (
        RunId        INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ActionType   NVARCHAR(20) NOT NULL,  -- Apply / Rollback / Validate / MetadataRefresh
        VersionNumber NVARCHAR(32) NULL,
        StartTime    DATETIME2 NOT NULL CONSTRAINT DF_MigRun_Start DEFAULT (SYSUTCDATETIME()),
        EndTime      DATETIME2 NULL,
        Status       NVARCHAR(20) NOT NULL,
        Details      NVARCHAR(MAX) NULL,
        ErrorMessage NVARCHAR(4000) NULL
    );
END
GO

/* ---------- Metadata: Application Modules ---------- */
IF OBJECT_ID(N'dbo.Meta_ApplicationModule', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Meta_ApplicationModule
    (
        ModuleId      INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ModuleCode    NVARCHAR(50) NOT NULL,
        ModuleName    NVARCHAR(200) NOT NULL,
        Description   NVARCHAR(500) NULL,
        IsActive      BIT NOT NULL CONSTRAINT DF_MetaModule_Active DEFAULT (1),
        SortOrder     INT NOT NULL CONSTRAINT DF_MetaModule_Sort DEFAULT (0),
        CreatedAt     DATETIME2 NOT NULL CONSTRAINT DF_MetaModule_Created DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_Meta_ApplicationModule_Code UNIQUE (ModuleCode)
    );
END
GO

/* ---------- Metadata: Configuration Categories ---------- */
IF OBJECT_ID(N'dbo.Meta_ConfigCategory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Meta_ConfigCategory
    (
        CategoryId    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        CategoryCode  NVARCHAR(50) NOT NULL,
        CategoryName  NVARCHAR(200) NOT NULL,
        ModuleCode    NVARCHAR(50) NULL,
        Description   NVARCHAR(500) NULL,
        IsActive      BIT NOT NULL CONSTRAINT DF_MetaConfigCat_Active DEFAULT (1),
        CreatedAt     DATETIME2 NOT NULL CONSTRAINT DF_MetaConfigCat_Created DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_Meta_ConfigCategory_Code UNIQUE (CategoryCode)
    );
END
GO

/* ---------- Metadata: Lookup Values ---------- */
IF OBJECT_ID(N'dbo.Meta_LookupValue', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Meta_LookupValue
    (
        LookupId      INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        CategoryCode  NVARCHAR(50) NOT NULL,
        LookupCode    NVARCHAR(50) NOT NULL,
        DisplayName   NVARCHAR(200) NOT NULL,
        Description   NVARCHAR(500) NULL,
        SortOrder     INT NOT NULL CONSTRAINT DF_MetaLookup_Sort DEFAULT (0),
        IsActive      BIT NOT NULL CONSTRAINT DF_MetaLookup_Active DEFAULT (1),
        ExtraJson     NVARCHAR(MAX) NULL,
        CreatedAt     DATETIME2 NOT NULL CONSTRAINT DF_MetaLookup_Created DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_Meta_LookupValue UNIQUE (CategoryCode, LookupCode)
    );

    CREATE INDEX IX_Meta_LookupValue_Category
        ON dbo.Meta_LookupValue (CategoryCode, IsActive, SortOrder) INCLUDE (LookupCode, DisplayName);
END
GO

/* ---------- Metadata: Audit Categories ---------- */
IF OBJECT_ID(N'dbo.Meta_AuditCategory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Meta_AuditCategory
    (
        AuditCategoryId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        CategoryCode    NVARCHAR(50) NOT NULL,
        CategoryName    NVARCHAR(200) NOT NULL,
        Description     NVARCHAR(500) NULL,
        SeverityDefault NVARCHAR(20) NOT NULL CONSTRAINT DF_MetaAuditCat_Sev DEFAULT (N'Info'),
        IsActive        BIT NOT NULL CONSTRAINT DF_MetaAuditCat_Active DEFAULT (1),
        CreatedAt       DATETIME2 NOT NULL CONSTRAINT DF_MetaAuditCat_Created DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_Meta_AuditCategory_Code UNIQUE (CategoryCode)
    );
END
GO

/* ---------- Validation findings ---------- */
IF OBJECT_ID(N'dbo.DataValidationLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DataValidationLog
    (
        ValidationId    BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RunId           INT NULL,
        CheckCode       NVARCHAR(50) NOT NULL,
        Severity        NVARCHAR(20) NOT NULL,
        EntityName      NVARCHAR(128) NOT NULL,
        EntityKey       NVARCHAR(100) NULL,
        ValidationDetail NVARCHAR(MAX) NOT NULL,
        DetectedAt      DATETIME2 NOT NULL CONSTRAINT DF_DataVal_At DEFAULT (SYSUTCDATETIME()),
        IsResolved      BIT NOT NULL CONSTRAINT DF_DataVal_Resolved DEFAULT (0),
        ResolvedAt      DATETIME2 NULL,
        ResolvedBy      NVARCHAR(100) NULL
    );

    CREATE INDEX IX_DataValidationLog_Detected
        ON dbo.DataValidationLog (DetectedAt DESC) INCLUDE (CheckCode, Severity, IsResolved);
END
GO

IF OBJECT_ID(N'dbo.DataValidationRunLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DataValidationRunLog
    (
        RunId            INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        JobName          NVARCHAR(128) NOT NULL,
        StartTime        DATETIME2 NOT NULL CONSTRAINT DF_DataValRun_Start DEFAULT (SYSUTCDATETIME()),
        EndTime          DATETIME2 NULL,
        Status           NVARCHAR(20) NOT NULL,
        ChecksRun        INT NULL,
        IssuesFound      INT NULL,
        Details          NVARCHAR(MAX) NULL,
        ErrorMessage     NVARCHAR(4000) NULL
    );
END
GO

/* ---------- Seed metadata ---------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Meta_ApplicationModule)
BEGIN
    INSERT INTO dbo.Meta_ApplicationModule (ModuleCode, ModuleName, Description, SortOrder) VALUES
        (N'AUTH', N'Authentication', N'Login, JWT, roles', 10),
        (N'LEAVE', N'Leave Management', N'Apply, approve, cancel leave', 20),
        (N'REPORT', N'Reporting', N'Operational leave reports', 30),
        (N'ANALYTICS', N'Analytics', N'Trends and forecasts', 40),
        (N'MAINT', N'Maintenance', N'Archival and DB maintenance', 50),
        (N'SECURITY', N'Security Ops', N'DDM, RLS, backup security', 60),
        (N'OPT', N'Optimization', N'Partitioning and indexes', 70),
        (N'COMPLIANCE', N'Audit Integrity', N'Auditing and compliance', 80),
        (N'CAPACITY', N'Capacity Performance', N'Capacity and SQL dashboard', 90),
        (N'MIGRATION', N'Migration Framework', N'Schema migrations and metadata', 100);
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Meta_ConfigCategory)
BEGIN
    INSERT INTO dbo.Meta_ConfigCategory (CategoryCode, CategoryName, ModuleCode, Description) VALUES
        (N'LEAVE_POLICY', N'Leave Policy Settings', N'LEAVE', N'Policy and entitlement settings'),
        (N'ALERT_THRESHOLDS', N'Alert Thresholds', N'CAPACITY', N'Capacity and performance alert thresholds'),
        (N'BACKUP', N'Backup Configuration', N'SECURITY', N'Backup paths and retention'),
        (N'ARCHIVE', N'Archive Retention', N'MAINT', N'Entity retention days'),
        (N'SYSTEM', N'System Settings', N'MIGRATION', N'Global application settings');
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Meta_LookupValue)
BEGIN
    INSERT INTO dbo.Meta_LookupValue (CategoryCode, LookupCode, DisplayName, SortOrder) VALUES
        (N'LEAVE_STATUS', N'Pending', N'Pending', 1),
        (N'LEAVE_STATUS', N'Approved', N'Approved', 2),
        (N'LEAVE_STATUS', N'Rejected', N'Rejected', 3),
        (N'LEAVE_STATUS', N'Cancelled', N'Cancelled', 4),
        (N'GENDER', N'M', N'Male', 1),
        (N'GENDER', N'F', N'Female', 2),
        (N'GENDER', N'O', N'Other', 3),
        (N'SEVERITY', N'Critical', N'Critical', 1),
        (N'SEVERITY', N'High', N'High', 2),
        (N'SEVERITY', N'Medium', N'Medium', 3),
        (N'SEVERITY', N'Low', N'Low', 4),
        (N'SEVERITY', N'Info', N'Info', 5);
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Meta_AuditCategory)
BEGIN
    INSERT INTO dbo.Meta_AuditCategory (CategoryCode, CategoryName, Description, SeverityDefault) VALUES
        (N'DML_CHANGE', N'Data Modification', N'Insert/Update/Delete on critical tables', N'Info'),
        (N'USER_ACTIVITY', N'User Activity', N'Login and application actions', N'Info'),
        (N'SECURITY', N'Security Event', N'Access and role changes', N'High'),
        (N'CONFIG_CHANGE', N'Configuration Change', N'Metadata and threshold changes', N'Medium'),
        (N'MIGRATION', N'Schema Migration', N'Migration apply/rollback events', N'High'),
        (N'VALIDATION', N'Data Validation', N'Validation check findings', N'Medium');
END
GO

/* Baseline migration record (framework installed) */
IF NOT EXISTS (SELECT 1 FROM dbo.SchemaMigrationHistory WHERE VersionNumber = N'0001.0000')
BEGIN
    INSERT INTO dbo.SchemaMigrationHistory
        (VersionNumber, MigrationName, ScriptName, Status, Notes, DownSql)
    VALUES
        (N'0001.0000', N'Baseline — Migration Framework installed',
         N'MIGRATION_FRAMEWORK_MASTER_DEPLOY.sql', N'Applied',
         N'Baseline marker; no rollback of framework core via DownSql.',
         N'/* Baseline cannot be rolled back automatically. */');
END
GO

PRINT '01_Migration_Metadata_Schema completed.';
GO
