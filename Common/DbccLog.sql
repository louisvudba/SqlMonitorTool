CREATE TABLE [dbo].[DbccLog]
    (
        [Id] INT IDENTITY(1, 1) NOT NULL,
        [DbId] BIGINT NULL,
        [DatabaseName] sysname NULL,
        [CommandId] INT NULL,
        [Error] BIGINT NULL,
        [Level] BIGINT NULL,
        [State] BIGINT NULL,
        [MessageText] VARCHAR(7000) NULL,
        [RepairLevel] VARCHAR(7000) NULL,
        [TimeStamp] DATETIMEOFFSET(7) NOT NULL,
        CONSTRAINT [PK_DbccLog]
            PRIMARY KEY CLUSTERED ([Id] ASC)
            WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON,
                  ALLOW_PAGE_LOCKS = ON
                 )
    )