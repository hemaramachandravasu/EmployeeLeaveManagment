-- Creates the central audit table for INSERT/UPDATE/DELETE operations
CREATE TABLE dbo.AuditLogs
(
	AuditId BIGINT IDENTITY(1,1) PRIMARY KEY,
	TableName SYSNAME NOT NULL,
	KeyValue NVARCHAR(200) NOT NULL,
	Operation CHAR(1) NOT NULL,
	OldValues NVARCHAR(MAX) NULL,
	NewValues NVARCHAR(MAX) NULL,
	ChangedBy NVARCHAR(200) NULL,
	ChangedAt DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
	TransactionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID()
);

CREATE INDEX IX_AuditLogs_TableDate ON dbo.AuditLogs(TableName, ChangedAt);
CREATE INDEX IX_AuditLogs_Key ON dbo.AuditLogs(KeyValue);

-- Create index on ChangedAt for time-based queries (filtered predicates with non-deterministic functions are not allowed in SQL Server)
CREATE INDEX IX_AuditLogs_ChangedAt ON dbo.AuditLogs(ChangedAt);
