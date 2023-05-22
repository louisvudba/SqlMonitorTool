CREATE TABLE [dbo].[WaitCategories](
	[wait_type] [nvarchar](60) NOT NULL,
	[wait_category] [nvarchar](128) NOT NULL,
	[ignorable] [bit] NULL,
CONSTRAINT PK_WaitCategories PRIMARY KEY CLUSTERED 
(
	[wait_type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
CREATE TABLE [dbo].[WaitStats](
	[pass] [tinyint] NULL,
	[sample_time] [datetimeoffset](7) NULL,
	[server_name] [nvarchar](50) NULL,
	[wait_type] [nvarchar](60) NULL,
	[wait_time_s] [numeric](12, 1) NULL,
	[wait_time_per_core_s] [decimal](18, 1) NULL,
	[signal_wait_time_s] [numeric](12, 1) NULL,
	[signal_wait_percent] [numeric](4, 1) NULL,
	[wait_count] [bigint] NULL,
	INDEX IX_pass NONCLUSTERED (
        [pass]
    )
) ON [PRIMARY]
GO