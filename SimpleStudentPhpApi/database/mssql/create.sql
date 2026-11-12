-- SimpleStudentPhpApi – Microsoft SQL Server (the mssqlserver Docker container)
--
-- Usually NOT needed: the .NET API creates the same database and table on start-up (EF Core EnsureCreated).
-- Use this script when you run only the PHP API against SQL Server.
--
--   docker cp database/mssql/create.sql mssqlserver:/tmp/create.sql
--   docker exec mssqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "1Secure*Password1" -No -f 65001 -i /tmp/create.sql
--   (-f 65001 = read the file as UTF-8, so "Kazlauskaitė" is stored correctly)
--
-- or open it in Azure Data Studio / SSMS (server localhost,1433). Safe to run more than once.

IF DB_ID('StudentDb') IS NULL
    CREATE DATABASE StudentDb;
GO

USE StudentDb;
GO

IF OBJECT_ID('dbo.Students', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Students (
        Id             INT           IDENTITY(1,1) NOT NULL PRIMARY KEY,
        FirstName      NVARCHAR(100) NOT NULL,
        LastName       NVARCHAR(100) NOT NULL,
        Email          NVARCHAR(200) NOT NULL,
        StudyProgram   NVARCHAR(100) NOT NULL,
        EnrollmentYear INT           NOT NULL
    );
END
GO

-- Demo data (only if the table is empty)
IF NOT EXISTS (SELECT 1 FROM dbo.Students)
BEGIN
    INSERT INTO dbo.Students (FirstName, LastName, Email, StudyProgram, EnrollmentYear) VALUES
        (N'Jonas', N'Jonaitis',     N'jonas@kk.lt', N'Computer Science', 2024),
        (N'Ieva',  N'Kazlauskaitė', N'ieva@kk.lt',  N'Computer Science', 2024),
        (N'Amir',  N'Haddad',       N'amir@kk.lt',  N'Software Systems', 2025);
END
GO
