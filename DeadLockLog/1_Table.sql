CREATE TABLE [dbo].[DeadlockLog] (
    [Id]             BIGINT         IDENTITY (1, 1) NOT NULL,
    [DatabaseName]   NVARCHAR (100) NULL,
    [Time]           DATETIME       NULL,
    [BlockedXactid]  BIGINT         NULL,
    [BlockingXactid] BIGINT         NULL,
    [BlockedQuery]   NVARCHAR (MAX) NULL,
    [BlockingQuery]  NVARCHAR (MAX) NULL,
    [LockMode]       NVARCHAR (5)   NULL,
    [XMLReport]      XML            NULL,
    CONSTRAINT [PK_DeadLockLog] PRIMARY KEY CLUSTERED ([Id] ASC) WITH (DATA_COMPRESSION = ROW)
);
GO
CREATE NONCLUSTERED INDEX [IX_Time] ON [dbo].[DeadlockLog]([Time] ASC)
    INCLUDE([DatabaseName], [BlockedXactid], [BlockingXactid], [BlockedQuery], [BlockingQuery], [LockMode], [XMLReport]) WITH (DATA_COMPRESSION = ROW)
