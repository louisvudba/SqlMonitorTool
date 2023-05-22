CREATE TABLE [dbo].[CommandLog](
  [Id] int IDENTITY(1,1) NOT NULL,
  [DatabaseName] sysname NULL,
  [SchemaName] sysname NULL,
  [ObjectName] sysname NULL,
  [ObjectType] char(2) NULL,
  [IndexName] sysname NULL,
  [IndexType] tinyint NULL,
  [StatisticsName] sysname NULL,
  [PartitionNumber] int NULL,
  [ExtendedInfo] xml NULL,
  [Command] Nvarchar(max) NOT NULL,
  [CommandType] Nvarchar(60) NOT NULL,
  [StartTime] DATETIMEOFFSET(7) NOT NULL,
  [EndTime] DATETIMEOFFSET(7) NULL,
  [ErrorNumber] int NULL,
  [ErrorMessage] Nvarchar(max) NULL,
 CONSTRAINT [PK_CommandLog] PRIMARY KEY CLUSTERED
(
  [Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
)