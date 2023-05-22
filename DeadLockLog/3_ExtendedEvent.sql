IF EXISTS (SELECT 1/0 FROM sys.server_event_sessions WHERE name = '{EVENT_NAME}')
    DROP EVENT SESSION [{EVENT_NAME}] ON SERVER 
    
CREATE EVENT SESSION [{EVENT_NAME}] ON SERVER
    ADD EVENT sqlserver.xml_deadlock_report (
        ACTION (sqlserver.client_app_name, sqlserver.client_hostname,
        sqlserver.database_id, sqlserver.database_name, sqlserver.plan_handle,
        sqlserver.sql_text, sqlserver.username))
    ADD TARGET package0.ring_buffer (SET max_events_limit = (1500),
                                        max_memory = (50000)) --Max 50MB : config số câu query trong buffer
    WITH (MAX_MEMORY = 4096 KB,
            EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
            MAX_DISPATCH_LATENCY = 1 SECONDS,
            MAX_EVENT_SIZE = 0 KB,
            MEMORY_PARTITION_MODE = NONE,
            TRACK_CAUSALITY = OFF,
            STARTUP_STATE = OFF);
GO
IF NOT EXISTS (SELECT 1/0 FROM sys.dm_xe_sessions WHERE [name] = '{EVENT_NAME}')
    ALTER EVENT SESSION [{EVENT_NAME}] ON SERVER STATE = START;