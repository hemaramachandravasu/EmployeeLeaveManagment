/*
================================================================================
  Filegroups, Partition Functions & Partition Schemes
  Database: EmployeeLeaveDb

  Strategy
  --------
  • LeaveRequests  → RANGE RIGHT on CreatedDate (yearly boundaries)
  • AuditLogs      → RANGE RIGHT on ChangedOn   (quarterly boundaries)

  Partition-aligned storage enables partition elimination for date-range
  queries and near-instant SWITCH archival of aged partitions.
================================================================================
*/
USE EmployeeLeaveDb;
GO

SET NOCOUNT ON;

/* ---------- Resolve instance data path ---------- */
DECLARE @DataPath NVARCHAR(4000) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(4000));
IF @DataPath IS NULL OR @DataPath = N''
    SET @DataPath = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\';
IF RIGHT(@DataPath, 1) <> N'\' SET @DataPath += N'\';

DECLARE @Sql NVARCHAR(MAX);

/* ---------- LeaveRequests yearly filegroups ---------- */
DECLARE @LeaveFgs TABLE (FgName SYSNAME, FileName NVARCHAR(260), BoundaryLabel NVARCHAR(20));
INSERT INTO @LeaveFgs (FgName, FileName, BoundaryLabel) VALUES
    (N'FG_Leave_Pre2024',  N'EmployeeLeaveDb_Leave_Pre2024.ndf',  N'Pre2024'),
    (N'FG_Leave_2024',     N'EmployeeLeaveDb_Leave_2024.ndf',     N'2024'),
    (N'FG_Leave_2025',     N'EmployeeLeaveDb_Leave_2025.ndf',     N'2025'),
    (N'FG_Leave_2026',     N'EmployeeLeaveDb_Leave_2026.ndf',     N'2026'),
    (N'FG_Leave_2027',     N'EmployeeLeaveDb_Leave_2027.ndf',     N'2027'),
    (N'FG_Leave_Future',   N'EmployeeLeaveDb_Leave_Future.ndf',   N'Future');

DECLARE @Fg SYSNAME, @Fn NVARCHAR(260), @Lbl NVARCHAR(20);
DECLARE leave_fg CURSOR LOCAL FAST_FORWARD FOR SELECT FgName, FileName, BoundaryLabel FROM @LeaveFgs;
OPEN leave_fg;
FETCH NEXT FROM leave_fg INTO @Fg, @Fn, @Lbl;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name = @Fg)
    BEGIN
        SET @Sql = N'ALTER DATABASE EmployeeLeaveDb ADD FILEGROUP ' + QUOTENAME(@Fg) + N';';
        EXEC sys.sp_executesql @Sql;
    END

    IF NOT EXISTS (
        SELECT 1
        FROM sys.database_files df
        INNER JOIN sys.filegroups fg ON df.data_space_id = fg.data_space_id
        WHERE fg.name = @Fg)
    BEGIN
        SET @Sql = N'ALTER DATABASE EmployeeLeaveDb ADD FILE (
            NAME = ' + QUOTENAME(N'Leave_' + @Lbl, '''') + N',
            FILENAME = ' + QUOTENAME(@DataPath + @Fn, '''') + N',
            SIZE = 16MB, FILEGROWTH = 16MB
        ) TO FILEGROUP ' + QUOTENAME(@Fg) + N';';
        EXEC sys.sp_executesql @Sql;
    END

    FETCH NEXT FROM leave_fg INTO @Fg, @Fn, @Lbl;
END
CLOSE leave_fg;
DEALLOCATE leave_fg;
GO

/* ---------- AuditLogs quarterly filegroups ---------- */
DECLARE @DataPath2 NVARCHAR(4000) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(4000));
IF @DataPath2 IS NULL OR @DataPath2 = N''
    SET @DataPath2 = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\';
IF RIGHT(@DataPath2, 1) <> N'\' SET @DataPath2 += N'\';

DECLARE @Sql2 NVARCHAR(MAX);
DECLARE @AuditFgs TABLE (FgName SYSNAME, FileName NVARCHAR(260), BoundaryLabel NVARCHAR(20));
INSERT INTO @AuditFgs (FgName, FileName, BoundaryLabel) VALUES
    (N'FG_Audit_Pre2025',   N'EmployeeLeaveDb_Audit_Pre2025.ndf',   N'Pre2025'),
    (N'FG_Audit_2025_Q1',   N'EmployeeLeaveDb_Audit_2025_Q1.ndf',   N'2025Q1'),
    (N'FG_Audit_2025_Q2',   N'EmployeeLeaveDb_Audit_2025_Q2.ndf',   N'2025Q2'),
    (N'FG_Audit_2025_Q3',   N'EmployeeLeaveDb_Audit_2025_Q3.ndf',   N'2025Q3'),
    (N'FG_Audit_2025_Q4',   N'EmployeeLeaveDb_Audit_2025_Q4.ndf',   N'2025Q4'),
    (N'FG_Audit_2026_Q1',   N'EmployeeLeaveDb_Audit_2026_Q1.ndf',   N'2026Q1'),
    (N'FG_Audit_2026_Q2',   N'EmployeeLeaveDb_Audit_2026_Q2.ndf',   N'2026Q2'),
    (N'FG_Audit_2026_Q3',   N'EmployeeLeaveDb_Audit_2026_Q3.ndf',   N'2026Q3'),
    (N'FG_Audit_2026_Q4',   N'EmployeeLeaveDb_Audit_2026_Q4.ndf',   N'2026Q4'),
    (N'FG_Audit_2027_Q1',   N'EmployeeLeaveDb_Audit_2027_Q1.ndf',   N'2027Q1'),
    (N'FG_Audit_2027_Q2',   N'EmployeeLeaveDb_Audit_2027_Q2.ndf',   N'2027Q2'),
    (N'FG_Audit_2027_Q3',   N'EmployeeLeaveDb_Audit_2027_Q3.ndf',   N'2027Q3'),
    (N'FG_Audit_2027_Q4',   N'EmployeeLeaveDb_Audit_2027_Q4.ndf',   N'2027Q4'),
    (N'FG_Audit_Future',    N'EmployeeLeaveDb_Audit_Future.ndf',    N'Future');

DECLARE @AFg SYSNAME, @AFn NVARCHAR(260), @ALbl NVARCHAR(20);
DECLARE audit_fg CURSOR LOCAL FAST_FORWARD FOR SELECT FgName, FileName, BoundaryLabel FROM @AuditFgs;
OPEN audit_fg;
FETCH NEXT FROM audit_fg INTO @AFg, @AFn, @ALbl;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name = @AFg)
    BEGIN
        SET @Sql2 = N'ALTER DATABASE EmployeeLeaveDb ADD FILEGROUP ' + QUOTENAME(@AFg) + N';';
        EXEC sys.sp_executesql @Sql2;
    END

    IF NOT EXISTS (
        SELECT 1
        FROM sys.database_files df
        INNER JOIN sys.filegroups fg ON df.data_space_id = fg.data_space_id
        WHERE fg.name = @AFg)
    BEGIN
        SET @Sql2 = N'ALTER DATABASE EmployeeLeaveDb ADD FILE (
            NAME = ' + QUOTENAME(N'Audit_' + @ALbl, '''') + N',
            FILENAME = ' + QUOTENAME(@DataPath2 + @AFn, '''') + N',
            SIZE = 8MB, FILEGROWTH = 8MB
        ) TO FILEGROUP ' + QUOTENAME(@AFg) + N';';
        EXEC sys.sp_executesql @Sql2;
    END

    FETCH NEXT FROM audit_fg INTO @AFg, @AFn, @ALbl;
END
CLOSE audit_fg;
DEALLOCATE audit_fg;
GO

/* ---------- Partition functions ---------- */
IF NOT EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = N'PF_LeaveByCreatedDate')
BEGIN
    CREATE PARTITION FUNCTION PF_LeaveByCreatedDate (DATETIME2)
    AS RANGE RIGHT FOR VALUES
    (
        '2024-01-01T00:00:00',
        '2025-01-01T00:00:00',
        '2026-01-01T00:00:00',
        '2027-01-01T00:00:00',
        '2028-01-01T00:00:00'
    );
    PRINT 'Created PF_LeaveByCreatedDate';
END
ELSE
    PRINT 'PF_LeaveByCreatedDate already exists';
GO

IF NOT EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = N'PF_AuditByChangedOn')
BEGIN
    CREATE PARTITION FUNCTION PF_AuditByChangedOn (DATETIME2)
    AS RANGE RIGHT FOR VALUES
    (
        '2025-01-01T00:00:00',
        '2025-04-01T00:00:00',
        '2025-07-01T00:00:00',
        '2025-10-01T00:00:00',
        '2026-01-01T00:00:00',
        '2026-04-01T00:00:00',
        '2026-07-01T00:00:00',
        '2026-10-01T00:00:00',
        '2027-01-01T00:00:00',
        '2027-04-01T00:00:00',
        '2027-07-01T00:00:00',
        '2027-10-01T00:00:00',
        '2028-01-01T00:00:00'
    );
    PRINT 'Created PF_AuditByChangedOn';
END
ELSE
    PRINT 'PF_AuditByChangedOn already exists';
GO

/* ---------- Partition schemes ---------- */
IF NOT EXISTS (SELECT 1 FROM sys.partition_schemes WHERE name = N'PS_LeaveByCreatedDate')
BEGIN
    CREATE PARTITION SCHEME PS_LeaveByCreatedDate
    AS PARTITION PF_LeaveByCreatedDate
    TO
    (
        FG_Leave_Pre2024,
        FG_Leave_2024,
        FG_Leave_2025,
        FG_Leave_2026,
        FG_Leave_2027,
        FG_Leave_Future
    );
    PRINT 'Created PS_LeaveByCreatedDate';
END
ELSE
    PRINT 'PS_LeaveByCreatedDate already exists';
GO

IF NOT EXISTS (SELECT 1 FROM sys.partition_schemes WHERE name = N'PS_AuditByChangedOn')
BEGIN
    CREATE PARTITION SCHEME PS_AuditByChangedOn
    AS PARTITION PF_AuditByChangedOn
    TO
    (
        FG_Audit_Pre2025,
        FG_Audit_2025_Q1,
        FG_Audit_2025_Q2,
        FG_Audit_2025_Q3,
        FG_Audit_2025_Q4,
        FG_Audit_2026_Q1,
        FG_Audit_2026_Q2,
        FG_Audit_2026_Q3,
        FG_Audit_2026_Q4,
        FG_Audit_2027_Q1,
        FG_Audit_2027_Q2,
        FG_Audit_2027_Q3,
        FG_Audit_2027_Q4,
        FG_Audit_Future
    );
    PRINT 'Created PS_AuditByChangedOn';
END
ELSE
    PRINT 'PS_AuditByChangedOn already exists';
GO

/* ---------- Config / run-log tables for optimization module ---------- */
IF OBJECT_ID(N'dbo.OptimizationRunLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.OptimizationRunLog
    (
        OptimizationRunId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        JobName           NVARCHAR(128) NOT NULL,
        StepName          NVARCHAR(128) NOT NULL,
        StartTime         DATETIME2 NOT NULL CONSTRAINT DF_OptRun_Start DEFAULT (SYSUTCDATETIME()),
        EndTime           DATETIME2 NULL,
        Status            NVARCHAR(20) NOT NULL,
        Details           NVARCHAR(MAX) NULL,
        ErrorMessage      NVARCHAR(4000) NULL
    );
END
GO

IF OBJECT_ID(N'dbo.PartitionBoundaryConfig', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PartitionBoundaryConfig
    (
        ConfigId          INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        TableName         NVARCHAR(128) NOT NULL,
        PartitionFunction NVARCHAR(128) NOT NULL,
        PartitionScheme   NVARCHAR(128) NOT NULL,
        PartitionColumn   NVARCHAR(128) NOT NULL,
        Granularity       NVARCHAR(20) NOT NULL,  -- Yearly | Quarterly
        LeadBoundaries    INT NOT NULL CONSTRAINT DF_PBC_Lead DEFAULT (1),
        IsActive          BIT NOT NULL CONSTRAINT DF_PBC_Active DEFAULT (1),
        Notes             NVARCHAR(500) NULL
    );

    INSERT INTO dbo.PartitionBoundaryConfig
        (TableName, PartitionFunction, PartitionScheme, PartitionColumn, Granularity, LeadBoundaries, Notes)
    VALUES
        (N'LeaveRequests', N'PF_LeaveByCreatedDate', N'PS_LeaveByCreatedDate', N'CreatedDate', N'Yearly', 1,
         N'Yearly RANGE RIGHT; extend FG_Leave_Future before year-end SPLIT'),
        (N'AuditLogs', N'PF_AuditByChangedOn', N'PS_AuditByChangedOn', N'ChangedOn', N'Quarterly', 2,
         N'Quarterly RANGE RIGHT; keep two lead empty partitions');
END
GO

PRINT '01_Filegroups_PartitionFunction completed.';
GO
