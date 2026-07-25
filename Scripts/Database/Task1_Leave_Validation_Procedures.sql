/*
  Task 1 leave SP validation patch.
  Safe to run on an existing EmployeeLeaveDb (does not drop tables).

  sqlcmd -S localhost -E -C -i Scripts\Database\Task1_Leave_Validation_Procedures.sql
*/
USE EmployeeLeaveDb;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ApplyLeave
    @EmployeeId         INT,
    @LeaveTypeId        INT,
    @StartDate          DATE,
    @EndDate            DATE,
    @Reason             NVARCHAR(500),
    @NewLeaveRequestId  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @NewLeaveRequestId = 0;

    IF @StartDate IS NULL OR @EndDate IS NULL OR @StartDate > @EndDate
        RETURN -3;

    IF @Reason IS NULL OR LTRIM(RTRIM(@Reason)) = N''
        RETURN 0;

    IF NOT EXISTS (SELECT 1 FROM dbo.Employees WHERE EmployeeId = @EmployeeId AND IsActive = 1)
        RETURN -1;

    IF NOT EXISTS (SELECT 1 FROM dbo.LeaveTypes WHERE LeaveTypeId = @LeaveTypeId AND IsActive = 1)
        RETURN -2;

    IF EXISTS (
        SELECT 1
        FROM dbo.LeaveRequests
        WHERE EmployeeId = @EmployeeId
          AND IsCancelled = 0
          AND Status IN (N'Pending', N'Approved')
          AND StartDate <= @EndDate
          AND EndDate >= @StartDate
    )
        RETURN -4;

    INSERT INTO dbo.LeaveRequests (EmployeeId, LeaveTypeId, StartDate, EndDate, Reason, Status)
    VALUES (@EmployeeId, @LeaveTypeId, @StartDate, @EndDate, @Reason, N'Pending');

    SET @NewLeaveRequestId = SCOPE_IDENTITY();
    RETURN @NewLeaveRequestId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_UpdateLeave
    @LeaveRequestId INT,
    @LeaveTypeId    INT,
    @StartDate      DATE,
    @EndDate        DATE,
    @Reason         NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.LeaveRequests WHERE LeaveRequestId = @LeaveRequestId)
        RETURN -1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.LeaveRequests
        WHERE LeaveRequestId = @LeaveRequestId
          AND Status = N'Pending'
          AND IsCancelled = 0
    )
        RETURN -2;

    IF NOT EXISTS (SELECT 1 FROM dbo.LeaveTypes WHERE LeaveTypeId = @LeaveTypeId AND IsActive = 1)
        RETURN -3;

    IF @StartDate IS NULL OR @EndDate IS NULL OR @StartDate > @EndDate
        RETURN -4;

    UPDATE dbo.LeaveRequests
    SET LeaveTypeId = @LeaveTypeId,
        StartDate = @StartDate,
        EndDate = @EndDate,
        Reason = @Reason,
        ModifiedDate = SYSUTCDATETIME()
    WHERE LeaveRequestId = @LeaveRequestId
      AND Status = N'Pending'
      AND IsCancelled = 0;

    RETURN 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CancelLeave
    @LeaveRequestId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.LeaveRequests WHERE LeaveRequestId = @LeaveRequestId)
        RETURN -1;

    UPDATE dbo.LeaveRequests
    SET IsCancelled = 1,
        Status = N'Cancelled',
        ModifiedDate = SYSUTCDATETIME()
    WHERE LeaveRequestId = @LeaveRequestId;

    RETURN 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_ApproveLeave
    @LeaveRequestId INT,
    @ApprovedBy     INT,
    @Remarks        NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.LeaveRequests WHERE LeaveRequestId = @LeaveRequestId)
        RETURN -1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.LeaveRequests
        WHERE LeaveRequestId = @LeaveRequestId
          AND Status = N'Pending'
          AND IsCancelled = 0
    )
        RETURN -2;

    IF NOT EXISTS (SELECT 1 FROM dbo.Employees WHERE EmployeeId = @ApprovedBy AND IsActive = 1)
        RETURN -3;

    UPDATE dbo.LeaveRequests
    SET Status = N'Approved',
        ApprovedBy = @ApprovedBy,
        ApprovedDate = SYSUTCDATETIME(),
        Remarks = @Remarks,
        ModifiedDate = SYSUTCDATETIME()
    WHERE LeaveRequestId = @LeaveRequestId
      AND Status = N'Pending'
      AND IsCancelled = 0;

    RETURN 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_RejectLeave
    @LeaveRequestId INT,
    @ApprovedBy     INT,
    @Remarks        NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.LeaveRequests WHERE LeaveRequestId = @LeaveRequestId)
        RETURN -1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.LeaveRequests
        WHERE LeaveRequestId = @LeaveRequestId
          AND Status = N'Pending'
          AND IsCancelled = 0
    )
        RETURN -2;

    IF NOT EXISTS (SELECT 1 FROM dbo.Employees WHERE EmployeeId = @ApprovedBy AND IsActive = 1)
        RETURN -3;

    UPDATE dbo.LeaveRequests
    SET Status = N'Rejected',
        ApprovedBy = @ApprovedBy,
        ApprovedDate = SYSUTCDATETIME(),
        Remarks = @Remarks,
        ModifiedDate = SYSUTCDATETIME()
    WHERE LeaveRequestId = @LeaveRequestId
      AND Status = N'Pending'
      AND IsCancelled = 0;

    RETURN 1;
END
GO
