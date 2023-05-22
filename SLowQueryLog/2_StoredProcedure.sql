CREATE PROCEDURE [dbo].[usp_Dba_SlowQueryLog]
AS
BEGIN
    -- Query ring buffer into temp table
    SELECT CAST(dt.target_data AS XML) AS xmlSlowData
    INTO #tempSlowQueryRingBuffer
    FROM sys.dm_xe_session_targets dt
        JOIN sys.dm_xe_sessions ds ON ds.Address = dt.event_session_address
        JOIN sys.server_event_sessions ss ON ds.Name = ss.Name
    WHERE dt.target_name = 'ring_buffer'
        AND ds.Name = '{EVENT_NAME}'

    -- Insert into table
    INSERT INTO [dbo].[SlowQueryLog]
    SELECT
        DATEADD(hh, 7, xed.event_data.value('(@timestamp)[1]', 'datetime')) AS [Time] --Add 7h because ext events takes UTC time
        , CONVERT (FLOAT, xed.event_data.value ('(data[@name=''duration'']/value)[1]', 'BIGINT')) / 1000000 AS [Duration(s)]
        , CONVERT (FLOAT, xed.event_data.value ('(data[@name=''cpu_time'']/value)[1]', 'BIGINT')) / 1000000 AS [CPUTime(s)]
        , xed.event_data.value ('(data[@name=''physical_reads'']/value)[1]', 'BIGINT') AS [PhysicalReads]
        , xed.event_data.value ('(data[@name=''logical_reads'']/value)[1]', 'BIGINT') AS [LogicalReads]
        , xed.event_data.value ('(data[@name=''writes'']/value)[1]', 'BIGINT') AS [Writes]
        , xed.event_data.value ('(action[@name=''username'']/value)[1]', 'NVARCHAR(100)') AS [User]
        , xed.event_data.value ('(action[@name=''client_app_name'']/value)[1]', 'NVARCHAR(100)') AS [AppName]
        , xed.event_data.value ('(action[@name=''database_name'']/value)[1]', 'NVARCHAR(100)') AS [Database]
        , ISNULL(xed.event_data.value('(data[@name=''statement'']/value)[1]', 'NVARCHAR(MAX)'),
                    xed.event_data.value('(data[@name=''batch_text'']/value)[1]', 'NVARCHAR(MAX)')) AS [STMT_Batch_Text] --sql statement text depending on rpc or stmt
        , xed.event_data.value('(action[@name=''sql_text'']/value)[1]', 'NVARCHAR(MAX)') AS [SQLText]
    FROM #tempSlowQueryRingBuffer
        CROSS APPLY xmlSlowData.nodes('//RingBufferTarget/event') AS xed (event_data)
    WHERE xed.event_data.value ('(action[@name=''database_id'']/value)[1]', 'bigint') > 4
END
