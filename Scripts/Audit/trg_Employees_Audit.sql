-- Trigger to audit INSERT/UPDATE/DELETE on dbo.Employees
CREATE TRIGGER dbo.trg_Employees_Audit
ON dbo.Employees
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
	SET NOCOUNT ON;

	INSERT INTO dbo.AuditLogs (TableName, KeyValue, Operation, OldValues, NewValues, ChangedBy)
	SELECT
		'Employees',
		CONCAT('Employee:', ISNULL(CONVERT(NVARCHAR(50), COALESCE(i.EmployeeId, d.EmployeeId)), '')),
		CASE
			WHEN i.EmployeeId IS NOT NULL AND d.EmployeeId IS NULL THEN 'I'
			WHEN i.EmployeeId IS NOT NULL AND d.EmployeeId IS NOT NULL THEN 'U'
			WHEN i.EmployeeId IS NULL AND d.EmployeeId IS NOT NULL THEN 'D'
			ELSE 'U' END,
		CASE WHEN d.EmployeeId IS NULL THEN NULL ELSE (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
			CASE WHEN i.EmployeeId IS NULL THEN NULL ELSE (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
			CONCAT(SUSER_SNAME(), ' | ', APP_NAME(), ' | ', HOST_NAME())
		FROM inserted i
		FULL OUTER JOIN deleted d ON i.EmployeeId = d.EmployeeId;
END
GO
