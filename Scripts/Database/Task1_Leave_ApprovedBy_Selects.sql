/*
  Include ApprovedBy / ApprovedDate on leave read procedures.
  sqlcmd -S localhost -E -C -i Scripts\Database\Task1_Leave_ApprovedBy_Selects.sql
*/
USE EmployeeLeaveDb;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetAllLeaveRequests
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        lr.LeaveRequestId,
        lr.EmployeeId,
        lr.LeaveTypeId,
        lr.StartDate,
        lr.EndDate,
        lr.TotalDays,
        lr.Reason,
        lr.Status,
        lr.ApprovedBy,
        lr.ApprovedDate,
        lr.Remarks,
        lr.IsCancelled
    FROM dbo.LeaveRequests lr
    WHERE lr.IsCancelled = 0
    ORDER BY lr.CreatedDate DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetLeaveById
    @LeaveRequestId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        lr.LeaveRequestId,
        lr.EmployeeId,
        lr.LeaveTypeId,
        lr.StartDate,
        lr.EndDate,
        lr.TotalDays,
        lr.Reason,
        lr.Status,
        lr.ApprovedBy,
        lr.ApprovedDate,
        lr.Remarks,
        lr.IsCancelled
    FROM dbo.LeaveRequests lr
    WHERE lr.LeaveRequestId = @LeaveRequestId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetLeaveHistory
    @EmployeeId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        lr.LeaveRequestId,
        lr.EmployeeId,
        lr.LeaveTypeId,
        lr.StartDate,
        lr.EndDate,
        lr.TotalDays,
        lr.Reason,
        lr.Status,
        lr.ApprovedBy,
        lr.ApprovedDate,
        lr.Remarks,
        lr.IsCancelled
    FROM dbo.LeaveRequests lr
    WHERE lr.EmployeeId = @EmployeeId
      AND lr.IsCancelled = 0
    ORDER BY lr.StartDate DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetPendingLeaveRequests
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        lr.LeaveRequestId,
        lr.EmployeeId,
        lr.LeaveTypeId,
        lr.StartDate,
        lr.EndDate,
        lr.TotalDays,
        lr.Reason,
        lr.Status,
        lr.ApprovedBy,
        lr.ApprovedDate,
        lr.Remarks,
        lr.IsCancelled
    FROM dbo.LeaveRequests lr
    WHERE lr.Status = N'Pending'
      AND lr.IsCancelled = 0
    ORDER BY lr.StartDate;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetLeavesByDateRange
    @FromDate DATE,
    @ToDate   DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        lr.LeaveRequestId,
        lr.EmployeeId,
        lr.LeaveTypeId,
        lr.StartDate,
        lr.EndDate,
        lr.TotalDays,
        lr.Reason,
        lr.Status,
        lr.ApprovedBy,
        lr.ApprovedDate,
        lr.Remarks,
        lr.IsCancelled
    FROM dbo.LeaveRequests lr
    WHERE lr.IsCancelled = 0
      AND lr.StartDate >= @FromDate
      AND lr.EndDate <= @ToDate
    ORDER BY lr.StartDate;
END
GO
