CREATE PROCEDURE [dbo].[usp_Dba_DeadLockLog]	
AS
BEGIN
    -- Query ring buffer data
    IF OBJECT_ID('tempdb..#tempDeadlockRingBuffer') IS NOT NULL
        DROP TABLE #tempDeadlockRingBuffer;   

    -- Query ring buffer into temp table
    SELECT  CAST(dt.target_data AS XML) AS xmlDeadlockData
    INTO    #tempDeadlockRingBuffer
    FROM    sys.dm_xe_session_targets dt
            JOIN sys.dm_xe_sessions ds ON ds.address = dt.event_session_address
            JOIN sys.server_event_sessions ss ON ds.name = ss.name
    WHERE   dt.target_name = 'ring_buffer'
            AND ds.name = '{EVENT_NAME}';

    ;WITH cte
    AS (
        SELECT  CASE WHEN xevents.event_data.query('(data[@name="blocked_process"]/value/blocked-process-report)[1]').value('(blocked-process-report[@monitorLoop])[1]', 'NVARCHAR(MAX)') IS NULL THEN xevents.event_data.value('(action[@name="database_name"]/value)[1]', 'NVARCHAR(100)') 
                ELSE xevents.event_data.value('(data[@name="database_name"]/value)[1]', 'NVARCHAR(100)') 
                END AS [DatabaseName],
                DATEADD(mi, DATEDIFF(mi, GETUTCDATE(), CURRENT_TIMESTAMP), xevents.event_data.value('(@timestamp)[1]', 'datetime2')) AS [Time],
                xevents.event_data.value('(data[@name="lock_mode"]/text)[1]', 'NVARCHAR(5)') AS [LockMode],
                xevents.event_data.query('(data[@name="xml_report"]/value/deadlock)[1]') AS [DeadlockGraph]
        FROM    #tempDeadlockRingBuffer
                CROSS APPLY xmlDeadlockData.nodes('//RingBufferTarget/event') AS xevents (event_data)
    )

    INSERT INTO DeadlockLog
    SELECT 
        [DatabaseName],
        [Time],
        CAST([DeadlockGraph] AS XML).value('(deadlock[1])/process-list[1]/process[1]/@xactid', 'bigint') AS [BlockedXactid],
        CAST([DeadlockGraph] AS XML).value('(deadlock[1])/process-list[1]/process[2]/@xactid', 'bigint') AS [BlockingXactid],
        CAST([DeadlockGraph] AS XML).value('(deadlock[1])/process-list[1]/process[1]/inputbuf[1]', 'nvarchar(max)') AS [BlockedQuery],
        CAST([DeadlockGraph] AS XML).value('(deadlock[1])/process-list[1]/process[2]/inputbuf[1]', 'nvarchar(max)') AS [BlockingQuery],
        CAST([DeadlockGraph] AS XML).value('(deadlock[1])/process-list[1]/process[2]/@lockMode', 'nvarchar(5)') AS [LockMode],
        [DeadlockGraph] AS [XMLReport]
    FROM cte
END;