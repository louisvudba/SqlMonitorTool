CREATE QUEUE BlockedProcessReportQueue
CREATE SERVICE BlockedProcessReportService
    ON QUEUE BlockedProcessReportQueue ([http://schemas.microsoft.com/SQL/Notifications/PostEventNotification])
CREATE EVENT NOTIFICATION BlockedProcessReport ON SERVER WITH fan_in FOR blocked_process_report TO SERVICE 'BlockedProcessReportService', 'current database'

ALTER QUEUE BlockedProcessReportQueue
WITH STATUS = ON,
    RETENTION = OFF,
    ACTIVATION(
        STATUS = ON,
        PROCEDURE_NAME = usp_Dba_ProcessBlockProcessReports,
        MAX_QUEUE_READERS = 1,
        EXECUTE AS OWNER
    )