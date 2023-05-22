CREATE PROCEDURE [dbo].[usp_Dba_IndexStats]
AS
BEGIN
	DELETE FROM dbo.IndexStats
    WHERE pass in (1,3);

    UPDATE dbo.IndexStats
    SET pass = IIF(pass = 2, 1, 3)
    WHERE pass IN (2,4);

    DECLARE @DatabaseName VARCHAR(50),
            @DatabaseId INT
    DECLARE @SampleTime DATETIMEOFFSET = SYSDATETIMEOFFSET();
    DECLARE @ServerName VARCHAR(50) = @@SERVERNAME;
    DECLARE @Command NVARCHAR(4000);

    SET @Command = N'USE ?
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
        INSERT EventMonitoring.dbo.IndexStats
        SELECT  2 AS pass,
                ''' + CAST(@SampleTime AS VARCHAR(100)) + ''',
                @@SERVERNAME AS server_name,
				DB_ID() AS database_id,
				DB_NAME() AS database_name, 
                so.object_id, 
                si.index_id, 
                si.type,                        
                COALESCE(sc.NAME, ''Unknown'') AS [schema_name],
                COALESCE(so.name, ''Unknown'') AS [object_name], 
                COALESCE(si.name, ''Unknown'') AS [index_name],
                CASE WHEN so.[type] = CAST(''V'' AS CHAR(2)) THEN ''View'' ELSE ''Table'' END,
                p.rows,
                si.is_unique, 
                si.is_primary_key, 
                CASE when si.type = 3 THEN 1 ELSE 0 END AS is_XML,
                CASE when si.type = 4 THEN 1 ELSE 0 END AS is_spatial,
                CASE when si.type = 6 THEN 1 ELSE 0 END AS is_NC_columnstore,
                CASE when si.type = 5 then 1 else 0 end as is_CX_columnstore,
                CASE when si.data_space_id = 0 then 1 else 0 end as is_in_memory_oltp,
                si.is_disabled,
                si.is_hypothetical, 
                si.is_padded, 
                si.fill_factor,                       
                CASE WHEN si.filter_definition IS NOT NULL THEN si.filter_definition
                        ELSE N''''
                END AS filter_definition,
                ISNULL(us.user_seeks, 0),
                ISNULL(us.user_scans, 0),
                ISNULL(us.user_lookups, 0),
                ISNULL(us.user_updates, 0),
                us.last_user_seek,
                us.last_user_scan,
                us.last_user_lookup,
                us.last_user_update,
                so.create_date,
                so.modify_date
        FROM    sys.indexes AS si WITH (NOLOCK)
                JOIN sys.objects AS so WITH (NOLOCK) ON si.object_id = so.object_id
                                        AND so.is_ms_shipped = 0 /*Exclude objects shipped by Microsoft*/
                                        AND so.type <> ''TF'' /*Exclude table valued functions*/
                JOIN sys.schemas sc ON so.schema_id = sc.schema_id
                LEFT JOIN sys.partitions p ON si.object_id = p.object_id AND si.index_id = p.index_id
                LEFT JOIN sys.dm_db_index_usage_stats AS us WITH (NOLOCK) ON si.[object_id] = us.[object_id]
                                                                AND si.index_id = us.index_id
                                                                AND us.database_id = DB_ID()
        WHERE    si.[type] IN (1, 2, 3, 4, 5, 6 ) 
        /* Include: Clustered, Conclustered, XML, Spatial, Cluster Columnstore, NC Columnstore | Exclude: Heaps - Type = 0 */ 
		OPTION    ( RECOMPILE );
    ';

    EXEC master..sp_foreachdb
        @command = @Command,
        @name_pattern = 'KiotViet',
		@ignore_pattern = 'Archived'

	INSERT INTO [dbo].[IndexStats] ([pass]
		  ,[sample_time]
		  ,[server_name]
		  ,[database_id]
		  ,[database_name]
		  ,[object_id]
		  ,[index_id]
		  ,[index_type]
		  ,[schema_name]
		  ,[object_name]
		  ,[index_name]) 
	SELECT DISTINCT
           4,
           SYSDATETIMEOFFSET(),
           @@SERVERNAME,
           a.database_id,
           b.name,
           a.object_id,
           -1,
           -1,
           'dbo',
           SUBSTRING(
                        statement,
                        LEN(statement) - CHARINDEX('[', REVERSE(statement)) + 2,
                        CHARINDEX('[', REVERSE(statement)) - 2
                    ),
           CONCAT(equality_columns, '|', inequality_columns, '|', included_columns) cc
    FROM sys.dm_db_missing_index_details a
        INNER JOIN sys.databases b
            ON a.database_id = b.database_id
    WHERE b.name LIKE 'KiotViet%'

    SELECT i2.[sample_time]
          ,i2.[server_name]
          ,i2.[database_id]
          ,i2.[database_name]
          ,i2.[object_id]
          ,i2.[index_id]
          ,i2.[index_type]
          ,i2.[schema_name]
          ,i2.[object_name]
          ,i2.[index_name]
          ,i2.[object_type]
          ,i2.[rows]
          ,i2.[is_unique]
          ,i2.[is_primary_key]
          ,i2.[is_XML]
          ,i2.[is_spatial]
          ,i2.[is_NC_columnstore]
          ,i2.[is_CX_columnstore]
          ,i2.[is_in_memory_oltp]
          ,i2.[is_disabled]
          ,i2.[is_hypothetical]
          ,i2.[is_padded]
          ,i2.[fill_factor]
          ,i2.[filter_definition]
          ,i2.[user_seeks] - ISNULL(i1.[user_seeks], 0) AS [user_seeks]
          ,i2.[user_scans] - ISNULL(i1.[user_scans], 0) AS [user_scans]
          ,i2.[user_lookups] - ISNULL(i1.[user_lookups], 0) AS [user_lookups]
          ,i2.[user_updates] - ISNULL(i1.[user_updates], 0) AS [user_updates]
          ,i2.[user_seeks] [total_seeks]
          ,i2.[user_scans] [total_scans]
          ,i2.[user_lookups] [total_lookups]
          ,i2.[user_updates] [total_updates]
          ,i2.[last_user_seek]
          ,i2.[last_user_scan]
          ,i2.[last_user_lookup]
          ,i2.[last_user_update]
          ,i2.[create_date]
          ,i2.[modify_date]
    FROM dbo.IndexStats i2
        LEFT OUTER JOIN dbo.IndexStats i1
            ON i1.database_name = i2.database_name AND i1.schema_name = i2.schema_name 
                AND i1.object_name = i2.object_name AND i1.index_name = i2.index_name
                AND i1.pass = 1
    WHERE i2.pass = 2
	UNION ALL
	SELECT i2.[sample_time]
          ,i2.[server_name]
          ,i2.[database_id]
          ,i2.[database_name]
          ,i2.[object_id]
          ,i2.[index_id]
          ,i2.[index_type]
          ,i2.[schema_name]
          ,i2.[object_name]
          ,i2.[index_name]
          ,i2.[object_type]
          ,i2.[rows]
          ,i2.[is_unique]
          ,i2.[is_primary_key]
          ,i2.[is_XML]
          ,i2.[is_spatial]
          ,i2.[is_NC_columnstore]
          ,i2.[is_CX_columnstore]
          ,i2.[is_in_memory_oltp]
          ,i2.[is_disabled]
          ,i2.[is_hypothetical]
          ,i2.[is_padded]
          ,i2.[fill_factor]
          ,i2.[filter_definition]
          ,i2.[user_seeks] [user_seeks]
          ,i2.[user_scans] [user_scans]
          ,i2.[user_lookups] [user_lookups]
          ,i2.[user_updates] [user_updates]
          ,i2.[user_seeks] [total_seeks]
          ,i2.[user_scans] [total_scans]
          ,i2.[user_lookups] [total_lookups]
          ,i2.[user_updates] [total_updates]
          ,i2.[last_user_seek]
          ,i2.[last_user_scan]
          ,i2.[last_user_lookup]
          ,i2.[last_user_update]
          ,i2.[create_date]
          ,i2.[modify_date]
    FROM dbo.IndexStats as i2 WHERE pass = 4
END