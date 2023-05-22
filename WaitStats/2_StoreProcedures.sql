CREATE PROCEDURE [dbo].[usp_Dba_WaitStats]
AS
BEGIN
	DELETE FROM dbo.WaitStats
    WHERE pass = 1;

    UPDATE dbo.WaitStats
    SET pass = 1
    WHERE pass = 2;

    IF NOT EXISTS (SELECT 1 / 0 FROM dbo.WaitStats WHERE pass = 1)
    BEGIN
        PRINT 1;
        WITH cte_WaitStats
        AS (SELECT x.wait_type,
                   SUM(x.sum_wait_time_ms) AS sum_wait_time_ms,
                   SUM(x.sum_signal_wait_time_ms) AS sum_signal_wait_time_ms,
                   SUM(x.sum_waiting_tasks) AS sum_waiting_tasks
            FROM
            (
                SELECT owt.wait_type,
                       SUM(owt.wait_duration_ms) OVER (PARTITION BY owt.wait_type, owt.session_id) AS sum_wait_time_ms,
                       0 AS sum_signal_wait_time_ms,
                       0 AS sum_waiting_tasks
                FROM sys.dm_os_waiting_tasks owt
                WHERE owt.session_id > 50
                      AND owt.wait_duration_ms >= 0
                UNION ALL
                SELECT os.wait_type,
                       SUM(os.wait_time_ms) OVER (PARTITION BY os.wait_type) AS sum_wait_time_ms,
                       SUM(os.signal_wait_time_ms) OVER (PARTITION BY os.wait_type) AS sum_signal_wait_time_ms,
                       SUM(os.waiting_tasks_count) OVER (PARTITION BY os.wait_type) AS sum_waiting_tasks
                FROM sys.dm_os_wait_stats os
            ) x
            GROUP BY x.wait_type)
        INSERT dbo.WaitStats
        (
            [pass],
            [sample_time],
            [server_name],
            [wait_type],
            [wait_time_s],
            [wait_time_per_core_s],
            [signal_wait_time_s],
            [signal_wait_percent],
            [wait_count]
        )
        SELECT 1,
               SYSDATETIMEOFFSET(),
               @@SERVERNAME,
               wc.wait_type,
               COALESCE(c.wait_time_s, 0),
               COALESCE(CAST((CAST(ws.sum_wait_time_ms AS MONEY)) / 1000.0 / cores.cpu_count AS DECIMAL(18, 1)), 0),
               COALESCE(c.signal_wait_time_s, 0),
               COALESCE(   CASE
                               WHEN c.wait_time_s > 0 THEN
                                   CAST(100. * (c.signal_wait_time_s / c.wait_time_s) AS NUMERIC(4, 1))
                               ELSE
                                   0
                           END,
                           0
                       ),
               COALESCE(ws.sum_waiting_tasks, 0)
        FROM dbo.WaitCategories wc
            LEFT JOIN cte_WaitStats ws
                ON wc.wait_type = ws.wait_type
                   AND ws.sum_waiting_tasks > 0
            CROSS APPLY
        (
            SELECT SUM(1) AS cpu_count
            FROM sys.dm_os_schedulers
            WHERE status = 'VISIBLE ONLINE'
                  AND is_online = 1
        ) AS cores
            CROSS APPLY
        (
            SELECT CAST(ws.sum_wait_time_ms / 1000. AS NUMERIC(12, 1)) AS wait_time_s,
                   CAST(ws.sum_signal_wait_time_ms / 1000. AS NUMERIC(12, 1)) AS signal_wait_time_s
        ) AS c;

        WAITFOR DELAY '00:00:05';
    END;

    WITH cte_WaitStats
    AS (SELECT x.wait_type,
               SUM(x.sum_wait_time_ms) AS sum_wait_time_ms,
               SUM(x.sum_signal_wait_time_ms) AS sum_signal_wait_time_ms,
               SUM(x.sum_waiting_tasks) AS sum_waiting_tasks
        FROM
        (
            SELECT owt.wait_type,
                   SUM(owt.wait_duration_ms) OVER (PARTITION BY owt.wait_type, owt.session_id) AS sum_wait_time_ms,
                   0 AS sum_signal_wait_time_ms,
                   0 AS sum_waiting_tasks
            FROM sys.dm_os_waiting_tasks owt
            WHERE owt.session_id > 50
                  AND owt.wait_duration_ms >= 0
            UNION ALL
            SELECT os.wait_type,
                   SUM(os.wait_time_ms) OVER (PARTITION BY os.wait_type) AS sum_wait_time_ms,
                   SUM(os.signal_wait_time_ms) OVER (PARTITION BY os.wait_type) AS sum_signal_wait_time_ms,
                   SUM(os.waiting_tasks_count) OVER (PARTITION BY os.wait_type) AS sum_waiting_tasks
            FROM sys.dm_os_wait_stats os
        ) x
        GROUP BY x.wait_type)
    INSERT dbo.WaitStats
    (
        [pass],
        [sample_time],
        [server_name],
        [wait_type],
        [wait_time_s],
        [wait_time_per_core_s],
        [signal_wait_time_s],
        [signal_wait_percent],
        [wait_count]
    )
    SELECT 2,
           SYSDATETIMEOFFSET(),
           @@SERVERNAME,
           wc.wait_type,
           COALESCE(c.wait_time_s, 0),
           COALESCE(CAST((CAST(ws.sum_wait_time_ms AS MONEY)) / 1000.0 / cores.cpu_count AS DECIMAL(18, 1)), 0),
           COALESCE(c.signal_wait_time_s, 0),
           COALESCE(   CASE
                           WHEN c.wait_time_s > 0 THEN
                               CAST(100. * (c.signal_wait_time_s / c.wait_time_s) AS NUMERIC(4, 1))
                           ELSE
                               0
                       END,
                       0
                   ),
           COALESCE(ws.sum_waiting_tasks, 0)
    FROM dbo.WaitCategories wc
        LEFT JOIN cte_WaitStats ws
            ON wc.wait_type = ws.wait_type
               AND ws.sum_waiting_tasks > 0
        CROSS APPLY
    (
        SELECT SUM(1) AS cpu_count
        FROM sys.dm_os_schedulers
        WHERE status = 'VISIBLE ONLINE'
              AND is_online = 1
    ) AS cores
        CROSS APPLY
    (
        SELECT CAST(ws.sum_wait_time_ms / 1000. AS NUMERIC(12, 1)) AS wait_time_s,
               CAST(ws.sum_signal_wait_time_ms / 1000. AS NUMERIC(12, 1)) AS signal_wait_time_s
    ) AS c;

    SELECT ws2.server_name,
           ws2.sample_time,
           DATEDIFF(ss, ws1.sample_time, ws2.sample_time) time_range,
           COALESCE(wc.wait_type, 'Other') wait_type,
           COALESCE(wc.wait_category, 'Other') wait_category,
           CASE WHEN ws2.wait_time_s > ws1.wait_time_s THEN COALESCE(ws2.wait_time_s - ws1.wait_time_s, 0) ELSE 0 END wait_time_s,
           COALESCE(ws2.wait_time_per_core_s - ws1.wait_time_per_core_s, 0) wait_time_per_core_s,
           COALESCE(ws2.signal_wait_time_s - ws1.signal_wait_time_s, 0) signal_wait_time_s,
           COALESCE(ws2.signal_wait_percent - ws1.signal_wait_percent, 0) signal_wait_percent,
           COALESCE(ws2.wait_count - ws1.wait_count, 0) wait_count,
           CASE
               WHEN ws2.wait_count > ws1.wait_count THEN
                   COALESCE(
                               CAST((ws2.wait_time_s - ws1.wait_time_s) * 1000.
                                    / (1.0 * (ws2.wait_count - ws1.wait_count)) AS NUMERIC(12, 1)),
                               0
                           )
               ELSE
                   0
           END avg_wait_per_ms,
           wc.ignorable
    FROM dbo.WaitStats ws2
        LEFT OUTER JOIN dbo.WaitStats ws1
            ON ws2.wait_type = ws1.wait_type
        LEFT JOIN dbo.WaitCategories wc
            ON ws2.wait_type = wc.wait_type
    WHERE ws1.pass = 1
          AND ws2.pass = 2;
END