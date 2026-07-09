/*
    ETL stored procedures for EmployeeLeaveDW
    Source: EmployeeLeaveDb (operational)
*/
USE EmployeeLeaveDW;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ETL_LogStart
    @ProcessName NVARCHAR(100),
    @ETLRunId    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.ETL_RunLog (ProcessName, StartTime, [Status])
    VALUES (@ProcessName, SYSUTCDATETIME(), N'Running');
    SET @ETLRunId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_ETL_LogEnd
    @ETLRunId      INT,
    @Status        NVARCHAR(20),
    @RowsInserted  INT = NULL,
    @RowsUpdated   INT = NULL,
    @ErrorMessage  NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.ETL_RunLog
    SET EndTime = SYSUTCDATETIME(),
        [Status] = @Status,
        RowsInserted = @RowsInserted,
        RowsUpdated = @RowsUpdated,
        ErrorMessage = @ErrorMessage
    WHERE ETLRunId = @ETLRunId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_ETL_LoadDimDate
    @StartDate DATE,
    @EndDate   DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ETLRunId INT;
    EXEC dbo.sp_ETL_LogStart @ProcessName = N'DimDate', @ETLRunId = @ETLRunId OUTPUT;

  BEGIN TRY
        DECLARE @DayCount INT = DATEDIFF(DAY, @StartDate, @EndDate) + 1;

        ;WITH Numbers AS
        (
            SELECT TOP (@DayCount)
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
            FROM sys.all_objects a
            CROSS JOIN sys.all_objects b
        )
        INSERT INTO dbo.DimDate
        (
            DateKey, [Date], [Year], [Quarter], [Month], MonthName,
            WeekOfYear, DayOfMonth, DayOfWeek, DayName, IsWeekend
        )
        SELECT
            CONVERT(INT, FORMAT(DATEADD(DAY, n.n, @StartDate), 'yyyyMMdd')),
            DATEADD(DAY, n.n, @StartDate),
            YEAR(DATEADD(DAY, n.n, @StartDate)),
            DATEPART(QUARTER, DATEADD(DAY, n.n, @StartDate)),
            MONTH(DATEADD(DAY, n.n, @StartDate)),
            DATENAME(MONTH, DATEADD(DAY, n.n, @StartDate)),
            DATEPART(WEEK, DATEADD(DAY, n.n, @StartDate)),
            DAY(DATEADD(DAY, n.n, @StartDate)),
            DATEPART(WEEKDAY, DATEADD(DAY, n.n, @StartDate)),
            DATENAME(WEEKDAY, DATEADD(DAY, n.n, @StartDate)),
            CASE WHEN DATENAME(WEEKDAY, DATEADD(DAY, n.n, @StartDate)) IN (N'Saturday', N'Sunday') THEN 1 ELSE 0 END
        FROM Numbers n
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.DimDate dd
            WHERE dd.DateKey = CONVERT(INT, FORMAT(DATEADD(DAY, n.n, @StartDate), 'yyyyMMdd'))
        );

        DECLARE @RowCount INT = @@ROWCOUNT;
        EXEC dbo.sp_ETL_LogEnd @ETLRunId, N'Success', @RowCount, 0;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        EXEC dbo.sp_ETL_LogEnd @ETLRunId, N'Failed', NULL, NULL, @ErrMsg;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_ETL_LoadDimDepartment
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ETLRunId INT;
    DECLARE @Now DATETIME2 = SYSUTCDATETIME();
    DECLARE @Inserted INT = 0;
    DECLARE @Updated INT = 0;

    EXEC dbo.sp_ETL_LogStart @ProcessName = N'DimDepartment', @ETLRunId = @ETLRunId OUTPUT;

    BEGIN TRY
        DECLARE @Changes TABLE
        (
            DepartmentId INT PRIMARY KEY,
            DepartmentCode NVARCHAR(50),
            DepartmentName NVARCHAR(100),
            IsActive BIT
        );

        INSERT INTO @Changes (DepartmentId, DepartmentCode, DepartmentName, IsActive)
        SELECT d.DepartmentId, d.DepartmentCode, d.DepartmentName, d.IsActive
        FROM EmployeeLeaveDb.dbo.Departments d;

        UPDATE tgt
        SET tgt.EffectiveTo = DATEADD(SECOND, -1, @Now)
        FROM dbo.DimDepartment tgt
        INNER JOIN @Changes src ON src.DepartmentId = tgt.DepartmentId
        WHERE tgt.EffectiveTo = '9999-12-31 23:59:59'
          AND (
                tgt.DepartmentCode <> src.DepartmentCode
             OR tgt.DepartmentName <> src.DepartmentName
             OR tgt.IsActive <> src.IsActive
          );
        SET @Updated = @@ROWCOUNT;

        INSERT INTO dbo.DimDepartment (DepartmentId, DepartmentCode, DepartmentName, IsActive, EffectiveFrom, EffectiveTo)
        SELECT src.DepartmentId, src.DepartmentCode, src.DepartmentName, src.IsActive, @Now, '9999-12-31 23:59:59'
        FROM @Changes src
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.DimDepartment tgt
            WHERE tgt.DepartmentId = src.DepartmentId
              AND tgt.EffectiveTo = '9999-12-31 23:59:59'
        );
        SET @Inserted = @@ROWCOUNT;

        EXEC dbo.sp_ETL_LogEnd @ETLRunId, N'Success', @Inserted, @Updated;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgDept NVARCHAR(4000) = ERROR_MESSAGE();
        EXEC dbo.sp_ETL_LogEnd @ETLRunId, N'Failed', NULL, NULL, @ErrMsgDept;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_ETL_LoadDimLeaveType
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ETLRunId INT;
    DECLARE @Now DATETIME2 = SYSUTCDATETIME();
    DECLARE @Inserted INT = 0;
    DECLARE @Updated INT = 0;

    EXEC dbo.sp_ETL_LogStart @ProcessName = N'DimLeaveType', @ETLRunId = @ETLRunId OUTPUT;

    BEGIN TRY
        DECLARE @Changes TABLE
        (
            LeaveTypeId INT PRIMARY KEY,
            LeaveTypeName NVARCHAR(100),
            TotalDaysEntitled INT
        );

        INSERT INTO @Changes (LeaveTypeId, LeaveTypeName, TotalDaysEntitled)
        SELECT lt.LeaveTypeId, lt.LeaveTypeName, lt.TotalDays
        FROM EmployeeLeaveDb.dbo.LeaveTypes lt;

        UPDATE tgt
        SET tgt.EffectiveTo = DATEADD(SECOND, -1, @Now)
        FROM dbo.DimLeaveType tgt
        INNER JOIN @Changes src ON src.LeaveTypeId = tgt.LeaveTypeId
        WHERE tgt.EffectiveTo = '9999-12-31 23:59:59'
          AND (
                tgt.LeaveTypeName <> src.LeaveTypeName
             OR ISNULL(tgt.TotalDaysEntitled, -1) <> ISNULL(src.TotalDaysEntitled, -1)
          );
        SET @Updated = @@ROWCOUNT;

        INSERT INTO dbo.DimLeaveType (LeaveTypeId, LeaveTypeName, TotalDaysEntitled, EffectiveFrom, EffectiveTo)
        SELECT src.LeaveTypeId, src.LeaveTypeName, src.TotalDaysEntitled, @Now, '9999-12-31 23:59:59'
        FROM @Changes src
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.DimLeaveType tgt
            WHERE tgt.LeaveTypeId = src.LeaveTypeId
              AND tgt.EffectiveTo = '9999-12-31 23:59:59'
        );
        SET @Inserted = @@ROWCOUNT;

        EXEC dbo.sp_ETL_LogEnd @ETLRunId, N'Success', @Inserted, @Updated;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgLt NVARCHAR(4000) = ERROR_MESSAGE();
        EXEC dbo.sp_ETL_LogEnd @ETLRunId, N'Failed', NULL, NULL, @ErrMsgLt;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_ETL_LoadDimEmployee
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ETLRunId INT;
    DECLARE @Now DATETIME2 = SYSUTCDATETIME();
    DECLARE @Inserted INT = 0;
    DECLARE @Updated INT = 0;

    EXEC dbo.sp_ETL_LogStart @ProcessName = N'DimEmployee', @ETLRunId = @ETLRunId OUTPUT;

    BEGIN TRY
        DECLARE @Source TABLE
        (
            EmployeeId INT PRIMARY KEY,
            EmployeeCode NVARCHAR(50),
            FirstName NVARCHAR(100),
            LastName NVARCHAR(100),
            DepartmentId INT,
            ManagerId INT NULL,
            IsActive BIT
        );

        INSERT INTO @Source
        SELECT e.EmployeeId, e.EmployeeCode, e.FirstName, e.LastName, e.DepartmentId, e.ManagerId, e.IsActive
        FROM EmployeeLeaveDb.dbo.Employees e;

        UPDATE tgt
        SET tgt.EffectiveTo = DATEADD(SECOND, -1, @Now)
        FROM dbo.DimEmployee tgt
        INNER JOIN @Source src ON src.EmployeeId = tgt.EmployeeId
        INNER JOIN dbo.DimDepartment dd ON dd.DepartmentId = src.DepartmentId AND dd.EffectiveTo = '9999-12-31 23:59:59'
        WHERE tgt.EffectiveTo = '9999-12-31 23:59:59'
          AND (
                tgt.EmployeeCode <> src.EmployeeCode
             OR tgt.FirstName <> src.FirstName
             OR tgt.LastName <> src.LastName
             OR tgt.DepartmentKey <> dd.DepartmentKey
             OR ISNULL(tgt.ManagerEmployeeId, -1) <> ISNULL(src.ManagerId, -1)
             OR tgt.IsActive <> src.IsActive
          );
        SET @Updated = @@ROWCOUNT;

        INSERT INTO dbo.DimEmployee
        (
            EmployeeId, EmployeeCode, FirstName, LastName, FullName,
            DepartmentKey, ManagerEmployeeId, IsActive, EffectiveFrom, EffectiveTo
        )
        SELECT
            src.EmployeeId,
            src.EmployeeCode,
            src.FirstName,
            src.LastName,
            CONCAT(src.FirstName, N' ', src.LastName),
            dd.DepartmentKey,
            src.ManagerId,
            src.IsActive,
            @Now,
            '9999-12-31 23:59:59'
        FROM @Source src
        INNER JOIN dbo.DimDepartment dd ON dd.DepartmentId = src.DepartmentId AND dd.EffectiveTo = '9999-12-31 23:59:59'
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.DimEmployee tgt
            WHERE tgt.EmployeeId = src.EmployeeId
              AND tgt.EffectiveTo = '9999-12-31 23:59:59'
        );
        SET @Inserted = @@ROWCOUNT;

        EXEC dbo.sp_ETL_LogEnd @ETLRunId, N'Success', @Inserted, @Updated;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgEmp NVARCHAR(4000) = ERROR_MESSAGE();
        EXEC dbo.sp_ETL_LogEnd @ETLRunId, N'Failed', NULL, NULL, @ErrMsgEmp;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_ETL_LoadFactLeaveRequests
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ETLRunId INT;
    DECLARE @LastLoadDate DATETIME2;
    DECLARE @Inserted INT = 0;
    DECLARE @Updated INT = 0;

    EXEC dbo.sp_ETL_LogStart @ProcessName = N'FactLeaveRequests', @ETLRunId = @ETLRunId OUTPUT;

    BEGIN TRY
        SELECT @LastLoadDate = MAX(EndTime)
        FROM dbo.ETL_RunLog
        WHERE ProcessName = N'FactLeaveRequests' AND [Status] = N'Success';

        IF @LastLoadDate IS NULL
            SET @LastLoadDate = '2000-01-01';

        DECLARE @Source TABLE
        (
            LeaveRequestId INT PRIMARY KEY,
            EmployeeKey INT NOT NULL,
            DepartmentKey INT NOT NULL,
            LeaveTypeKey INT NOT NULL,
            StartDateKey INT NOT NULL,
            EndDateKey INT NOT NULL,
            RequestDateKey INT NOT NULL,
            [Status] NVARCHAR(50) NOT NULL,
            IsCancelled BIT NOT NULL,
            DaysRequested DECIMAL(10,2) NOT NULL,
            DaysApproved DECIMAL(10,2) NOT NULL,
            DaysRejected DECIMAL(10,2) NOT NULL,
            SourceModifiedAt DATETIME2 NOT NULL
        );

        INSERT INTO @Source
        SELECT
            lr.LeaveRequestId,
            de.EmployeeKey,
            dd.DepartmentKey,
            dlt.LeaveTypeKey,
            CONVERT(INT, FORMAT(lr.StartDate, 'yyyyMMdd')),
            CONVERT(INT, FORMAT(lr.EndDate, 'yyyyMMdd')),
            CONVERT(INT, FORMAT(lr.CreatedDate, 'yyyyMMdd')),
            lr.[Status],
            lr.IsCancelled,
            CAST(lr.TotalDays AS DECIMAL(10,2)),
            CASE WHEN lr.[Status] = N'Approved' AND lr.IsCancelled = 0 THEN CAST(lr.TotalDays AS DECIMAL(10,2)) ELSE 0 END,
            CASE WHEN lr.[Status] = N'Rejected' AND lr.IsCancelled = 0 THEN CAST(lr.TotalDays AS DECIMAL(10,2)) ELSE 0 END,
            lr.CreatedDate
        FROM EmployeeLeaveDb.dbo.LeaveRequests lr
        INNER JOIN EmployeeLeaveDb.dbo.Employees e ON e.EmployeeId = lr.EmployeeId
        INNER JOIN dbo.DimEmployee de ON de.EmployeeId = e.EmployeeId AND de.EffectiveTo = '9999-12-31 23:59:59'
        INNER JOIN dbo.DimDepartment dd ON dd.DepartmentId = e.DepartmentId AND dd.EffectiveTo = '9999-12-31 23:59:59'
        INNER JOIN dbo.DimLeaveType dlt ON dlt.LeaveTypeId = lr.LeaveTypeId AND dlt.EffectiveTo = '9999-12-31 23:59:59'
        WHERE lr.CreatedDate > @LastLoadDate
           OR EXISTS
           (
               SELECT 1
               FROM dbo.FactLeaveRequests f
               WHERE f.SourceLeaveRequestId = lr.LeaveRequestId
                 AND (
                        f.[Status] <> lr.[Status]
                     OR f.IsCancelled <> lr.IsCancelled
                     OR f.DaysRequested <> CAST(lr.TotalDays AS DECIMAL(10,2))
                 )
           );

        SELECT @Inserted = COUNT(*)
        FROM @Source s
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.FactLeaveRequests f
            WHERE f.SourceLeaveRequestId = s.LeaveRequestId
        );

        SET @Updated = (SELECT COUNT(*) FROM @Source) - @Inserted;

        MERGE dbo.FactLeaveRequests AS tgt
        USING @Source AS src
            ON tgt.SourceLeaveRequestId = src.LeaveRequestId
        WHEN MATCHED THEN
            UPDATE SET
                EmployeeKey = src.EmployeeKey,
                DepartmentKey = src.DepartmentKey,
                LeaveTypeKey = src.LeaveTypeKey,
                StartDateKey = src.StartDateKey,
                EndDateKey = src.EndDateKey,
                RequestDateKey = src.RequestDateKey,
                [Status] = src.[Status],
                IsCancelled = src.IsCancelled,
                DaysRequested = src.DaysRequested,
                DaysApproved = src.DaysApproved,
                DaysRejected = src.DaysRejected,
                SourceModifiedAt = src.SourceModifiedAt,
                LoadTimestamp = SYSUTCDATETIME()
        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                EmployeeKey, DepartmentKey, LeaveTypeKey,
                StartDateKey, EndDateKey, RequestDateKey,
                [Status], IsCancelled,
                DaysRequested, DaysApproved, DaysRejected,
                SourceLeaveRequestId, SourceModifiedAt
            )
            VALUES
            (
                src.EmployeeKey, src.DepartmentKey, src.LeaveTypeKey,
                src.StartDateKey, src.EndDateKey, src.RequestDateKey,
                src.[Status], src.IsCancelled,
                src.DaysRequested, src.DaysApproved, src.DaysRejected,
                src.LeaveRequestId, src.SourceModifiedAt
            );

        EXEC dbo.sp_ETL_LogEnd @ETLRunId, N'Success', @Inserted, @Updated;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgFact NVARCHAR(4000) = ERROR_MESSAGE();
        EXEC dbo.sp_ETL_LogEnd @ETLRunId, N'Failed', NULL, NULL, @ErrMsgFact;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_ETL_RunNightly
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ETLRunId INT;
    DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);
    DECLARE @StartRange DATE = DATEADD(YEAR, -5, @Today);
    DECLARE @EndRange DATE = DATEADD(YEAR, 1, @Today);

    EXEC dbo.sp_ETL_LogStart @ProcessName = N'NightlyETL', @ETLRunId = @ETLRunId OUTPUT;

    BEGIN TRY
        EXEC dbo.sp_ETL_LoadDimDate @StartDate = @StartRange, @EndDate = @EndRange;
        EXEC dbo.sp_ETL_LoadDimDepartment;
        EXEC dbo.sp_ETL_LoadDimLeaveType;
        EXEC dbo.sp_ETL_LoadDimEmployee;
        EXEC dbo.sp_ETL_LoadFactLeaveRequests;

        EXEC dbo.sp_ETL_LogEnd @ETLRunId, N'Success', NULL, NULL;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgNight NVARCHAR(4000) = ERROR_MESSAGE();
        EXEC dbo.sp_ETL_LogEnd @ETLRunId, N'Failed', NULL, NULL, @ErrMsgNight;
        THROW;
    END CATCH
END
GO

PRINT 'ETL stored procedures created successfully.';
GO
