CREATE PROCEDURE [dbo].[usp_Dba_ProcessBlockProcessReports]
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @message_body XML,
            @message_type INT,
            @subject VARCHAR(MAX),
            @body VARCHAR(MAX),
            @dialog UNIQUEIDENTIFIER,
            @dbName VARCHAR(50),           
            @lastBlockedXactId BIGINT,
            @lastBlockingXactId BIGINT,
            @isBlkSource BIT,
            @blockedSQLText NVARCHAR(MAX),
            @blockingSQLText NVARCHAR(MAX),
            @lastId BIGINT,
            @emailQueue INT,
            @receipt_db NVARCHAR(500);

    SET @receipt_db = 'AA'

    WHILE (1 = 1)
    BEGIN
        BEGIN TRANSACTION;
            -- Receive the next available message from the queue
            WAITFOR
            (
                RECEIVE TOP (1) @message_type = message_type_id,
                                @message_body = CAST(message_body AS XML),
                                @dialog = conversation_handle
                FROM dbo.BlockedProcessReportQueue
            ),
            TIMEOUT 1000;

            -- If we didn't get anything, bail out
            IF (@@ROWCOUNT = 0)
            BEGIN
                ROLLBACK TRANSACTION;
                BREAK;
            END;

            ------------------------------------------------
            -- Log block events
            INSERT INTO [dbo].[BlockedProcessReports]
            (
                database_name,
                post_time,
                wait_time,
                blocked_xactid,
                blocking_xactid,
                is_blocking_source,
                blocked_inputbuf,
                blocking_inputbuf,
                blocked_process_report
            )
            SELECT DB_NAME(CAST(@message_body AS XML).value('(/EVENT_INSTANCE/DatabaseID)[1]', 'int')) AS database_name,
                CAST(@message_body AS XML).value('(/EVENT_INSTANCE/PostTime)[1]', 'datetime') AS post_time,
                CAST(@message_body AS XML).value('(/EVENT_INSTANCE/TextData/blocked-process-report/.)[1]/blocked-process[1]/process[1]/@waittime', 'int') AS wait_time,
                CAST(@message_body AS XML).value('(/EVENT_INSTANCE/TextData/blocked-process-report/.)[1]/blocked-process[1]/process[1]/@xactid', 'bigint') AS blocked_xactid,
                CAST(@message_body AS XML).value('(/EVENT_INSTANCE/TextData/blocked-process-report/.)[1]/blocking-process[1]/process[1]/@xactid', 'bigint') AS blocking_xactid,
                CASE
                    WHEN CAST(@message_body AS XML).value('(/EVENT_INSTANCE/TextData/blocked-process-report/.)[1]/blocking-process[1]/process[1]/@waitresource', 'nvarchar(max)') IS NULL 
                    THEN 1
                    ELSE 0 
                END AS is_blocking_source,
                CAST(@message_body AS XML).value('(/EVENT_INSTANCE/TextData/blocked-process-report/.)[1]/blocked-process[1]/process[1]/inputbuf[1]', 'nvarchar(max)') AS blocked_inputbuf,
                CAST(@message_body AS XML).value('(/EVENT_INSTANCE/TextData/blocked-process-report/.)[1]/blocking-process[1]/process[1]/inputbuf[1]', 'nvarchar(max)') AS blocking_inputbuf,
                CAST(@message_body AS XML).query('(/EVENT_INSTANCE/TextData/blocked-process-report/.)[1]') AS blocked_process_report;

            SET @dbName = NULL;
            SET @lastBlockedXactId = NULL;
            SET @lastBlockingXactId = NULL;
            SET @isBlkSource = NULL;
            SET @lastId = IDENT_CURRENT('BlockedProcessReports'); --Get the lastest report ID for further processing

            ------------------------------------------------
            -- Get XactID for lastest report. Just inserted above.
            SELECT @lastBlockedXactId = blocked_xactid,
                   @lastBlockingXactId = blocking_xactid,
                   @isBlkSource = is_blocking_source,
                   @dbName = database_name
            FROM BlockedProcessReports
            WHERE Id = @lastId;

            DECLARE @BlockedSQlHandle VARBINARY(MAX) = ISNULL(CONVERT(XML, @message_body).query('/EVENT_INSTANCE[1]/TextData[1]/*').value(
                'xs:hexBinary(substring((/blocked-process-report[1]/blocked-process[1]/process[1]/executionStack[1]/frame[1]/@sqlhandle)[1],3))',
                'varbinary(max)'), 0x
            )
            DECLARE @BlockingSQlHandle VARBINARY(MAX) = ISNULL(CONVERT(XML, @message_body).query('/EVENT_INSTANCE[1]/TextData[1]/*').value(
                'xs:hexBinary(substring((/blocked-process-report[1]/blocking-process[1]/process[1]/executionStack[1]/frame[1]/@sqlhandle)[1],3))',
                'varbinary(max)'), 0x
            )
                
            SET @blockedSQLText = NULL;
            SET @blockingSQLText = NULL;

            IF (@BlockedSQlHandle != 0x)
                SELECT @blockedSQLText = [text] FROM sys.dm_exec_sql_text(@BlockedSQlHandle)
            IF (@BlockingSQlHandle != 0x)
                SELECT @blockingSQLText = [text] FROM sys.dm_exec_sql_text(@BlockingSQlHandle)

            -- Insert full query into log table
            INSERT INTO BlockedProcessReportsDetail VALUES (@lastId, @blockedSQLText, @blockingSQLText)

        COMMIT TRANSACTION;
    END;
END;