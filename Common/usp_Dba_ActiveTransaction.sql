CREATE PROCEDURE dbo.usp_Dba_ActiveTransaction
AS
BEGIN
    SELECT DISTINCT @@SERVERNAME server_name
		, ToDateTimeOffset(GETDATE(),DATEPART(TZOFFSET, SYSDATETIMEOFFSET())) [Time]
		, FORMAT(GETDATE(),'HH') hour_check
		, s.session_id
		, a.transaction_id
		, a.name
		, STUFF(
			(SELECT ',' + DB_NAME(database_id) FROM sys.dm_tran_database_transactions WHERE transaction_id = a.transaction_id ORDER BY database_id DESC FOR XML PATH ('')), 1, 1, ''
			) database_name
		, (SELECT TOP 1 client_net_address FROM sys.[dm_exec_connections] c WHERE s.session_id  = c.session_id) client_net_address
		, se.login_name
		, se.host_name
		, se.program_name
		, duration = DATEDIFF(SECOND,a.transaction_begin_time,GETDATE())
		, ToDateTimeOffset(a.transaction_begin_time,DATEPART(TZOFFSET, SYSDATETIMEOFFSET())) transaction_begin_time 
		, transaction_type = CASE a.transaction_type
					WHEN 1 THEN 'Read/write transaction'
					WHEN 2 THEN 'Read-only transaction'
					WHEN 3 THEN 'System transaction'
					WHEN 4 THEN 'Distributed transaction'
			 END
		, transaction_state = CASE a.transaction_state
					WHEN 0 THEN 'The transaction has not been completely initialized yet.'
					WHEN 1 THEN 'The transaction has been initialized but has not started.'
					WHEN 2 THEN 'transaction is active.'
					WHEN 3 THEN 'The transaction has ended. This is used for read-only transactions.'
					WHEN 4 THEN 'The commit process has been initiated on the distributed transaction. The distributed transaction is still active but further processing cannot take place.'
					WHEN 5 THEN 'The transaction is in a prepared state and waiting resolution.'
					WHEN 6 THEN 'The transaction has been committed.'
					WHEN 7 THEN 'The transaction is being rolled back.'
					WHEN 8 THEN 'The transaction has been rolled back.'
			 END
		, dtc_state = CASE a.dtc_state WHEN 1 THEN 'ACTIVE' WHEN 2 THEN 'PREPARED' WHEN 3 THEN 'COMMITTED' WHEN 4 THEN 'ABORTED' WHEN 5 THEN 'RECOVERED' END
		, [Initiator] = CASE s.is_user_transaction WHEN 0 THEN 'System' ELSE 'User' END
		, [Is_Local] = CASE s.is_local WHEN 0 THEN 'No' ELSE 'Yes' END
		, [Transaction_Text] = IsNull((SELECT text FROM sys.dm_exec_sql_text(sp.[sql_handle])),'')
	FROM sys.dm_tran_active_transactions a
		LEFT JOIN sys.dm_tran_session_transactions s ON a.transaction_id=s.transaction_id
		LEFT JOIN sys.dm_exec_sessions se on s.session_id = se.session_id
		OUTER APPLY (SELECT TOP 1 [sql_handle] FROM sys.sysprocesses WHERE spid = s.session_id AND [sql_handle] <> 0x0000000000000000000000000000000000000000) sp
	WHERE s.session_id is Not Null
		AND DATEDIFF(SECOND,a.transaction_begin_time,GETDATE()) > 60
		AND a.[name] NOT IN ('CheckDb')
	ORDER BY s.session_id, transaction_begin_time
	OPTION (RECOMPILE);
END