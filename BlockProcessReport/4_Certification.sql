:Setvar CertName "BlockProcessReport"
:Setvar CertPath "C:\Cert\"
:Setvar CertEncryptPass "abc"
:Setvar TrustLogin "EventMonitoringLogin"

IF NOT EXISTS (SELECT 1/0 FROM sys.certificates WHERE name = '$(CertName)')
    CREATE CERTIFICATE [$(CertName)]
        ENCRYPTION BY PASSWORD = '$(CertEncryptPass)'
        WITH SUBJECT = 'Certificate for event monitoring'

IF EXISTS (
    SELECT 1/0 
    FROM sys.crypt_properties cp
        INNER JOIN sys.objects obj        ON obj.object_id = cp.major_id
        LEFT   JOIN sys.certificates c    ON c.thumbprint = cp.thumbprint
        LEFT   JOIN sys.asymmetric_keys a ON a.thumbprint = cp.thumbprint
    WHERE obj.name = 'usp_Dba_ProcessBlockProcessReports'
)
    DROP SIGNATURE FROM OBJECT::[dbo].[usp_Dba_ProcessBlockProcessReports] BY CERTIFICATE [$(CertName)]

ADD SIGNATURE TO OBJECT::[dbo].[usp_Dba_ProcessBlockProcessReports]
    BY CERTIFICATE [$(CertName)]
    WITH PASSWORD = '$(CertEncryptPass)'

DECLARE @FilePath NVARCHAR(1000) = '$(CertPath)$(CertName)_' + FORMAT(GETDATE(),'yyyymmddhhmmss') + '.cer'
DECLARE @Sql NVARCHAR(4000) 
SET @Sql = 'BACKUP CERTIFICATE [$(CertName)] TO FILE = ''' + @FilePath + ''''
EXEC sp_executesql @Sql

USE [master]

IF EXISTS (SELECT 1/0 FROM sys.server_principals WHERE name = '$(TrustLogin)' AND type_desc = 'CERTIFICATE_MAPPED_LOGIN')
	DROP LOGIN [$(TrustLogin)]

IF EXISTS (SELECT 1/0 FROM sys.certificates WHERE name = '$(CertName)')
    DROP CERTIFICATE [$(CertName)] 

SET @Sql = 'CREATE CERTIFICATE [$(CertName)] FROM FILE = ''' + @FilePath + ''''
EXEC sp_executesql @Sql

IF NOT EXISTS (SELECT 1/0 FROM sys.sql_logins WHERE name = '$(TrustLogin)')
    CREATE LOGIN [$(TrustLogin)] FROM CERTIFICATE [$(CertName)]

GRANT VIEW SERVER STATE, AUTHENTICATE SERVER TO [$(TrustLogin)]
GO