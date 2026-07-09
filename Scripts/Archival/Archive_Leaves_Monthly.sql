-- Archive Leaves older than retention (example retention = 3 years)
-- Intended to be run as a SQL Agent monthly job.
BEGIN TRAN;
	-- Ensure archive table exists with same schema (create it once manually or via script)
	INSERT INTO dbo.LeavesArchive WITH (TABLOCK)
	SELECT * FROM dbo.Leaves
	WHERE FromDate < DATEADD(year, -3, GETDATE()) AND Status = 'Closed';

	DELETE L
	FROM dbo.Leaves L
	WHERE L.FromDate < DATEADD(year, -3, GETDATE()) AND L.Status = 'Closed';
COMMIT TRAN;
GO
