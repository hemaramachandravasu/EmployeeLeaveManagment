/*
  Employee CRUD validation patch (safe on existing DB).
  sqlcmd -S localhost -E -C -i Scripts\Database\Task1_Employee_CRUD_Procedures.sql
*/
USE EmployeeLeaveDb;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AddEmployee
    @EmployeeCode   NVARCHAR(50),
    @FirstName      NVARCHAR(100),
    @LastName       NVARCHAR(100) = NULL,
    @Gender         NVARCHAR(20),
    @DateOfBirth    DATE,
    @MobileNumber   NVARCHAR(20),
    @Email          NVARCHAR(320),
    @DepartmentId   INT,
    @ManagerId      INT = NULL,
    @JoinDate       DATE,
    @Salary         DECIMAL(18,2),
    @Address        NVARCHAR(500) = NULL,
    @NewEmployeeId  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @NewEmployeeId = 0;

    IF NOT EXISTS (SELECT 1 FROM dbo.Departments WHERE DepartmentId = @DepartmentId)
        RETURN -1;

    IF EXISTS (SELECT 1 FROM dbo.Employees WHERE EmployeeCode = @EmployeeCode)
        RETURN -2;

    IF @ManagerId IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM dbo.Employees WHERE EmployeeId = @ManagerId AND IsActive = 1)
        RETURN -3;

    INSERT INTO dbo.Employees (
        EmployeeCode, FirstName, LastName, Gender, DateOfBirth, MobileNumber, Email,
        DepartmentId, ManagerId, JoinDate, Salary, Address
    )
    VALUES (
        @EmployeeCode, @FirstName, @LastName, @Gender, @DateOfBirth, @MobileNumber, @Email,
        @DepartmentId, @ManagerId, @JoinDate, @Salary, @Address
    );

    SET @NewEmployeeId = SCOPE_IDENTITY();
    RETURN @NewEmployeeId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_UpdateEmployee
    @EmployeeId     INT,
    @EmployeeCode   NVARCHAR(50),
    @FirstName      NVARCHAR(100),
    @LastName       NVARCHAR(100) = NULL,
    @Gender         NVARCHAR(20),
    @DateOfBirth    DATE,
    @MobileNumber   NVARCHAR(20),
    @Email          NVARCHAR(320),
    @DepartmentId   INT,
    @ManagerId      INT = NULL,
    @JoinDate       DATE,
    @Salary         DECIMAL(18,2),
    @Address        NVARCHAR(500) = NULL,
    @IsActive       BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Employees WHERE EmployeeId = @EmployeeId)
        RETURN -1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Departments WHERE DepartmentId = @DepartmentId)
        RETURN -2;

    IF EXISTS (
        SELECT 1
        FROM dbo.Employees
        WHERE EmployeeCode = @EmployeeCode
          AND EmployeeId <> @EmployeeId
    )
        RETURN -3;

    IF @ManagerId IS NOT NULL AND @ManagerId = @EmployeeId
        RETURN -5;

    IF @ManagerId IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM dbo.Employees WHERE EmployeeId = @ManagerId AND IsActive = 1)
        RETURN -4;

    UPDATE dbo.Employees
    SET EmployeeCode = @EmployeeCode,
        FirstName = @FirstName,
        LastName = @LastName,
        Gender = @Gender,
        DateOfBirth = @DateOfBirth,
        MobileNumber = @MobileNumber,
        Email = @Email,
        DepartmentId = @DepartmentId,
        ManagerId = @ManagerId,
        JoinDate = @JoinDate,
        Salary = @Salary,
        Address = @Address,
        IsActive = @IsActive
    WHERE EmployeeId = @EmployeeId;

    RETURN 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteEmployee
    @EmployeeId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Employees WHERE EmployeeId = @EmployeeId)
        RETURN -1;

    IF EXISTS (SELECT 1 FROM dbo.Employees WHERE EmployeeId = @EmployeeId AND IsActive = 0)
        RETURN -2;

    UPDATE dbo.Employees
    SET IsActive = 0
    WHERE EmployeeId = @EmployeeId
      AND IsActive = 1;

    RETURN 1;
END
GO
