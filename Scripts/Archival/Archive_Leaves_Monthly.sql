-- DEPRECATED: Use Scripts/Maintenance/02_Archive_Procedures.sql
-- Prefer: EXEC dbo.sp_Archive_RunAll;  (or Agent job ELM_Archive_Execution)
-- This stub remains for backward compatibility with older documentation.
USE EmployeeLeaveDb;
GO
EXEC dbo.sp_Maint_RunArchiveJob;
GO
