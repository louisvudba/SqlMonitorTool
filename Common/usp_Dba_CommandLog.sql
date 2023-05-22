CREATE PROCEDURE dbo.usp_Dba_CommandLog
    @DatabaseName sysname = NULL,
    @SchemaName sysname = NULL,
    @ObjectName sysname = NULL,
    @ObjectType CHAR(2) = NULL,
    @IndexName sysname = NULL,
    @IndexType TINYINT = NULL,
    @StatisticsName sysname = NULL,
    @PartitionNumber INT = NULL,
    @ExtendedInfo XML = NULL,
    @Command NVARCHAR(max) = NULL,
    @CommandType NVARCHAR(60) = NULL,
    @StartTime DATETIMEOFFSET(7) = NULL,
    @EndTime DATETIMEOFFSET(7) = NULL,
    @ErrorNumber INT = NULL,
    @ErrorMessage NVARCHAR(max) = NULL,
    @Id INT OUTPUT
AS
BEGIN
    INSERT INTO dbo.CommandLog
    (
        DatabaseName,
        SchemaName,
        ObjectName,
        ObjectType,
        IndexName,
        IndexType,
        StatisticsName,
        PartitionNumber,
        ExtendedInfo,
        CommandType,
        Command,
        StartTime,
        EndTime,
        ErrorNumber,
        ErrorMessage
    )
    VALUES
    (@DatabaseName, @SchemaName, @ObjectName, @ObjectType, @IndexName, @IndexType, @StatisticsName, @PartitionNumber,
     @ExtendedInfo, @CommandType, @Command, @StartTime, @EndTime, @ErrorNumber, @ErrorMessage)

    SET @Id = SCOPE_IDENTITY()
END