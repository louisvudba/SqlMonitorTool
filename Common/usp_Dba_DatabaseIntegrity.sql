CREATE PROCEDURE dbo.usp_Dba_DatabaseIntegrity
    @DatabaseName NVARCHAR(max) = NULL,
    @CheckCommands NVARCHAR(max) = 'CHECKDB',
    @PhysicalOnly NVARCHAR(max) = 'N',
    @DataPurity NVARCHAR(max) = 'N',
    @NoIndex NVARCHAR(max) = 'N',
    @ExtendedLogicalChecks NVARCHAR(max) = 'N',
    @TabLock NVARCHAR(max) = 'N',
    @MaxDOP INT = NULL,
    @LockTimeout INT = NULL,
    @Comment NVARCHAR(max) = NULL,
    @TimeLimitFrom TIME,
    @TimeLimitTo TIME
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @StartMessage NVARCHAR(max),
            @EndMessage NVARCHAR(max),
            @ErrorMessage NVARCHAR(max),
            @ErrorMessageOriginal NVARCHAR(max)

    DECLARE @Error INT = 0,
            @ReturnCode INT = 0

    DECLARE @StartTime DATETIMEOFFSET(7),
            @EndTime DATETIMEOFFSET(7)
    DECLARE @EmptyLine NVARCHAR(max) = CHAR(9)

    DECLARE @Command NVARCHAR(max) = N'',
            @LogId INT = 0

    DECLARE @DbccResult TABLE
    (
        [Error] BIGINT NULL,
        [Level] BIGINT NULL,
        [State] BIGINT NULL,
        [MessageText] VARCHAR(7000) NULL,
        [RepairLevel] VARCHAR(7000) NULL,
        [Status] BIGINT NULL,
        [DbId] BIGINT NULL,
        [DbFragId] BIGINT NULL,
        [ObjectId] BIGINT NULL,
        [IndexId] BIGINT NULL,
        [PartitionId] BIGINT NULL,
        [AllocUnitId] BIGINT NULL,
        [RidDbId] BIGINT NULL,
        [RidPruId] BIGINT NULL,
        [File] BIGINT NULL,
        [Page] BIGINT NULL,
        [Slot] BIGINT NULL,
        [RefDbId] BIGINT NULL,
        [RefPruId] BIGINT NULL,
        [RefFile] BIGINT NULL,
        [RefPage] BIGINT NULL,
        [RefSlot] BIGINT NULL,
        [Allocation] BIGINT NULL
    )

    /* Generate Command */
    IF @LockTimeout IS NOT NULL
        SET @Command = 'SET LOCK_TIMEOUT ' + CAST(@LockTimeout * 1000 AS NVARCHAR) + '; '
    SET @Command += 'DBCC CHECKDB (' + QUOTENAME(@DatabaseName)
    IF @NoIndex = 'Y'
        SET @Command += ', NOINDEX'
    SET @Command += ') WITH NO_INFOMSGS, ALL_ERRORMSGS, TABLERESULTS'
    IF @DataPurity = 'Y'
        SET @Command += ', DATA_PURITY'
    IF @PhysicalOnly = 'Y'
        SET @Command += ', PHYSICAL_ONLY'
    IF @ExtendedLogicalChecks = 'Y'
        SET @Command += ', EXTENDED_LOGICAL_CHECKS'
    IF @TabLock = 'Y'
        SET @Command += ', TABLOCK'
    IF @MaxDOP IS NOT NULL
        SET @Command += ', MAXDOP = ' + CAST(@MaxDOP AS NVARCHAR)

    /* Start Logging */
    SET @StartTime = SYSDATETIMEOFFSET()

    SET @StartMessage = 'Date and time: ' + CONVERT(NVARCHAR, @StartTime, 120)
    RAISERROR('%s', 10, 1, @StartMessage) WITH NOWAIT

    SET @StartMessage = 'Database context: ' + QUOTENAME(@DatabaseName)
    RAISERROR('%s', 10, 1, @StartMessage) WITH NOWAIT

    SET @StartMessage = 'Command: ' + @Command
    RAISERROR('%s', 10, 1, @StartMessage) WITH NOWAIT

    IF @Comment IS NOT NULL
    BEGIN
        SET @StartMessage = 'Comment: ' + @Comment
        RAISERROR('%s', 10, 1, @StartMessage) WITH NOWAIT
    END

    EXEC dbo.usp_Dba_CommandLog @DatabaseName = @DatabaseName,
                                @Command = @Command,
                                @CommandType = @CheckCommands,
                                @StartTime = @StartTime,
                                @Id = @LogId OUTPUT

    INSERT INTO @DbccResult
    (
        [Error],
        [Level],
        [State],
        MessageText,
        RepairLevel,
        [Status],
        [DbId],
        DbFragId,
        ObjectId,
        IndexId,
        PartitionId,
        AllocUnitId,
        RidDbId,
        RidPruId,
        [File],
        Page,
        Slot,
        RefDbId,
        RefPruId,
        RefFile,
        RefPage,
        RefSlot,
        Allocation
    )
    EXECUTE sp_executesql @stmt = @Command

    SET @EndTime = SYSDATETIMEOFFSET()

    IF @@ROWCOUNT <> 0
    BEGIN
        SELECT TOP 1
               @Error = [Error],
               @ErrorMessage = [MessageText]
        FROM @DbccResult
    END

    SET @ReturnCode = @Error

    /* End Logging */
    SET @EndMessage = 'Outcome: ' + IIF(@Error = 0, 'Succeeded', 'Failed')
    RAISERROR('%s', 10, 1, @EndMessage) WITH NOWAIT

    SET @EndMessage
        = 'Duration: '
          + IIF((DATEDIFF(SECOND, @StartTime, @EndTime) / (24 * 3600)) > 0,
                CAST((DATEDIFF(SECOND, @StartTime, @EndTime) / (24 * 3600)) AS NVARCHAR) + '.',
                '') + CONVERT(NVARCHAR, DATEADD(SECOND, DATEDIFF(SECOND, @StartTime, @EndTime), '1900-01-01'), 108)
    RAISERROR('%s', 10, 1, @EndMessage) WITH NOWAIT

    SET @EndMessage = 'Date and time: ' + CONVERT(NVARCHAR, @EndTime, 120)
    RAISERROR('%s', 10, 1, @EndMessage) WITH NOWAIT

    RAISERROR(@EmptyLine, 10, 1) WITH NOWAIT

    INSERT [DbccLog]
    (
        [DbId],
        [DatabaseName],
        [CommandId],
        [Error],
        [Level],
        [State],
        [MessageText],
        [RepairLevel],
        [TimeStamp]
    )
    SELECT [DbId],
           @DatabaseName,
           @LogId,
           [Error],
           [Level],
           [State],
           [MessageText],
           [RepairLevel],
           @EndTime
    FROM @DbccResult

    UPDATE dbo.CommandLog
    SET EndTime = @EndTime,
        ErrorNumber = @Error,
        ErrorMessage = @ErrorMessage
    WHERE Id = @LogId

    IF @ReturnCode <> 0
    BEGIN
        RETURN @ReturnCode
    END
END
