/*
    Employee Leave Management - Data Warehouse Star Schema
    Database: EmployeeLeaveDW (separate from operational EmployeeLeaveDb)
    Run on SQL Server 2019+ with access to EmployeeLeaveDb on the same instance.
*/
USE master;
GO

IF DB_ID(N'EmployeeLeaveDW') IS NULL
    CREATE DATABASE EmployeeLeaveDW;
GO

USE EmployeeLeaveDW;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.FactLeaveRequests', N'U') IS NOT NULL DROP TABLE dbo.FactLeaveRequests;
IF OBJECT_ID(N'dbo.DimEmployee', N'U') IS NOT NULL DROP TABLE dbo.DimEmployee;
IF OBJECT_ID(N'dbo.DimDepartment', N'U') IS NOT NULL DROP TABLE dbo.DimDepartment;
IF OBJECT_ID(N'dbo.DimLeaveType', N'U') IS NOT NULL DROP TABLE dbo.DimLeaveType;
IF OBJECT_ID(N'dbo.DimDate', N'U') IS NOT NULL DROP TABLE dbo.DimDate;
IF OBJECT_ID(N'dbo.ETL_RunLog', N'U') IS NOT NULL DROP TABLE dbo.ETL_RunLog;
GO

CREATE TABLE dbo.DimDate
(
    DateKey      INT          NOT NULL PRIMARY KEY,
    [Date]       DATE         NOT NULL,
    [Year]       INT          NOT NULL,
    [Quarter]    TINYINT      NOT NULL,
    [Month]      TINYINT      NOT NULL,
    MonthName    NVARCHAR(20) NOT NULL,
    WeekOfYear   TINYINT      NOT NULL,
    DayOfMonth   TINYINT      NOT NULL,
    DayOfWeek    TINYINT      NOT NULL,
    DayName      NVARCHAR(20) NOT NULL,
    IsWeekend    BIT          NOT NULL,
    CONSTRAINT UQ_DimDate_Date UNIQUE ([Date])
);
GO

CREATE TABLE dbo.DimDepartment
(
    DepartmentKey   INT           IDENTITY(1,1) NOT NULL PRIMARY KEY,
    DepartmentId    INT           NOT NULL,
    DepartmentCode  NVARCHAR(50)  NOT NULL,
    DepartmentName  NVARCHAR(100) NOT NULL,
    IsActive        BIT           NOT NULL,
    EffectiveFrom   DATETIME2     NOT NULL,
    EffectiveTo     DATETIME2     NOT NULL
);
GO

CREATE UNIQUE INDEX UX_DimDepartment_Current
    ON dbo.DimDepartment (DepartmentId)
    WHERE EffectiveTo = CONVERT(DATETIME2, '9999-12-31 23:59:59', 126);
GO

CREATE TABLE dbo.DimLeaveType
(
    LeaveTypeKey      INT           IDENTITY(1,1) NOT NULL PRIMARY KEY,
    LeaveTypeId       INT           NOT NULL,
    LeaveTypeName     NVARCHAR(100) NOT NULL,
    TotalDaysEntitled INT           NULL,
    EffectiveFrom     DATETIME2     NOT NULL,
    EffectiveTo       DATETIME2     NOT NULL
);
GO

CREATE UNIQUE INDEX UX_DimLeaveType_Current
    ON dbo.DimLeaveType (LeaveTypeId)
    WHERE EffectiveTo = CONVERT(DATETIME2, '9999-12-31 23:59:59', 126);
GO

CREATE TABLE dbo.DimEmployee
(
    EmployeeKey         INT           IDENTITY(1,1) NOT NULL PRIMARY KEY,
    EmployeeId          INT           NOT NULL,
    EmployeeCode        NVARCHAR(50)  NOT NULL,
    FirstName           NVARCHAR(100) NOT NULL,
    LastName            NVARCHAR(100) NOT NULL,
    FullName            NVARCHAR(201) NOT NULL,
    DepartmentKey       INT           NOT NULL,
    ManagerEmployeeId   INT           NULL,
    IsActive            BIT           NOT NULL,
    EffectiveFrom       DATETIME2     NOT NULL,
    EffectiveTo         DATETIME2     NOT NULL,
    CONSTRAINT FK_DimEmployee_Department FOREIGN KEY (DepartmentKey) REFERENCES dbo.DimDepartment (DepartmentKey)
);
GO

CREATE UNIQUE INDEX UX_DimEmployee_Current
    ON dbo.DimEmployee (EmployeeId)
    WHERE EffectiveTo = CONVERT(DATETIME2, '9999-12-31 23:59:59', 126);
GO

CREATE TABLE dbo.FactLeaveRequests
(
    FactLeaveRequestId   BIGINT         IDENTITY(1,1) NOT NULL PRIMARY KEY,
    EmployeeKey          INT            NOT NULL,
    DepartmentKey        INT            NOT NULL,
    LeaveTypeKey         INT            NOT NULL,
    StartDateKey         INT            NOT NULL,
    EndDateKey           INT            NOT NULL,
    RequestDateKey       INT            NOT NULL,
    [Status]             NVARCHAR(50)   NOT NULL,
    IsCancelled          BIT            NOT NULL,
    DaysRequested        DECIMAL(10,2)  NOT NULL,
    DaysApproved         DECIMAL(10,2)  NOT NULL,
    DaysRejected         DECIMAL(10,2)  NOT NULL,
    SourceLeaveRequestId INT            NOT NULL,
    SourceModifiedAt     DATETIME2      NOT NULL,
    LoadTimestamp        DATETIME2      NOT NULL CONSTRAINT DF_FactLeaveRequests_LoadTimestamp DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT FK_FactLeaveRequests_Employee FOREIGN KEY (EmployeeKey) REFERENCES dbo.DimEmployee (EmployeeKey),
    CONSTRAINT FK_FactLeaveRequests_Department FOREIGN KEY (DepartmentKey) REFERENCES dbo.DimDepartment (DepartmentKey),
    CONSTRAINT FK_FactLeaveRequests_LeaveType FOREIGN KEY (LeaveTypeKey) REFERENCES dbo.DimLeaveType (LeaveTypeKey),
    CONSTRAINT FK_FactLeaveRequests_StartDate FOREIGN KEY (StartDateKey) REFERENCES dbo.DimDate (DateKey),
    CONSTRAINT FK_FactLeaveRequests_EndDate FOREIGN KEY (EndDateKey) REFERENCES dbo.DimDate (DateKey),
    CONSTRAINT FK_FactLeaveRequests_RequestDate FOREIGN KEY (RequestDateKey) REFERENCES dbo.DimDate (DateKey),
    CONSTRAINT UQ_FactLeaveRequests_Source UNIQUE (SourceLeaveRequestId)
);
GO

CREATE INDEX IX_FactLeaveRequests_DeptDate ON dbo.FactLeaveRequests (DepartmentKey, StartDateKey);
CREATE INDEX IX_FactLeaveRequests_EmployeeDate ON dbo.FactLeaveRequests (EmployeeKey, StartDateKey);
CREATE INDEX IX_FactLeaveRequests_LeaveTypeDate ON dbo.FactLeaveRequests (LeaveTypeKey, StartDateKey);
GO

CREATE TABLE dbo.ETL_RunLog
(
    ETLRunId      INT            IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ProcessName   NVARCHAR(100)  NOT NULL,
    StartTime     DATETIME2      NOT NULL,
    EndTime       DATETIME2      NULL,
    [Status]      NVARCHAR(20)   NOT NULL,
    RowsInserted  INT            NULL,
    RowsUpdated   INT            NULL,
    ErrorMessage  NVARCHAR(4000) NULL
);
GO

PRINT 'EmployeeLeaveDW star schema created successfully.';
GO
