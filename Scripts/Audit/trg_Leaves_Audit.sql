-- Trigger to audit INSERT/UPDATE/DELETE on dbo.Leaves
CREATE TRIGGER dbo.trg_Leaves_Audit
ON dbo.Leaves
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
	SET NOCOUNT ON;

	INSERT INTO dbo.AuditLogs (TableName, KeyValue, Operation, OldValues, NewValues, ChangedBy)
	SELECT
		'Leaves',
		CONCAT('Leave:', ISNULL(CONVERT(NVARCHAR(50), COALESCE(i.LeaveId, d.LeaveId)), '')),
		CASE
			WHEN i.LeaveId IS NOT NULL AND d.LeaveId IS NULL THEN 'I'
			WHEN i.LeaveId IS NOT NULL AND d.LeaveId IS NOT NULL THEN 'U'
			WHEN i.LeaveId IS NULL AND d.LeaveId IS NOT NULL THEN 'D'
			ELSE 'U' END,
		CASE WHEN d.LeaveId IS NULL THEN NULL ELSE (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
			CASE WHEN i.LeaveId IS NULL THEN NULL ELSE (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
			CONCAT(SUSER_SNAME(), ' | ', APP_NAME(), ' | ', HOST_NAME())
		FROM inserted i
		FULL OUTER JOIN deleted d ON i.LeaveId = d.LeaveId;
END
GO
