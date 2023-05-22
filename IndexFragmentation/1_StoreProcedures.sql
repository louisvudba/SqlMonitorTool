CREATE PROCEDURE [dbo].[usp_Dba_IndexFragmentation]
AS
BEGIN
	DECLARE @Command NVARCHAR (4000);
	SET @Command = N'USE ?
		SELECT @@SERVERNAME server_name,
			ToDateTimeOffset(GETDATE(),DATEPART(TZOFFSET, SYSDATETIMEOFFSET())) [Time],
			FORMAT(GETDATE(),''HH'') hour_check,
			DB_NAME() AS database_name, 
			object_name(i.OBJECT_ID) AS table_name, 
			i.index_id, 
			i.name AS index_name,
			s.index_type_desc,
			s.avg_fragmentation_in_percent, 
			s.avg_page_space_used_in_percent, 
			s.avg_fragment_size_in_pages, 
			s.record_count, 
			s.page_count, 
			s.index_level,
			s.alloc_unit_type_desc,
			s.fragment_count 
		FROM sys.dm_db_index_physical_stats(DB_ID(),NULL, NULL, NULL, ''SAMPLED'') s
			JOIN sys.tables t WITH (NOLOCK) ON s.OBJECT_ID = t.OBJECT_ID
			JOIN sys.indexes i WITH (NOLOCK) ON s.OBJECT_ID = i.OBJECT_ID AND s.index_id = i.index_id
		WHERE t.is_ms_shipped = 0';

	EXEC master..sp_foreachdb
		@command = @Command
END