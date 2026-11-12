-- SimpleStudentPhpApi – MySQL / MariaDB (XAMPP)
-- Run in phpMyAdmin (tab "SQL" or "Import") or:  mysql -u root < database/mysql/create.sql
-- Safe to run more than once.

SET NAMES utf8mb4;   -- read this file as UTF-8 (Lithuanian letters: ą č ę ė į š ų ū ž)

CREATE DATABASE IF NOT EXISTS StudentDb
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE StudentDb;

-- Same table and column names as the SQL Server table created by the .NET API (EF Core),
-- so the PHP API can work with either database without changing any SQL.
CREATE TABLE IF NOT EXISTS Students (
    Id             INT          NOT NULL AUTO_INCREMENT,
    FirstName      VARCHAR(100) NOT NULL,
    LastName       VARCHAR(100) NOT NULL,
    Email          VARCHAR(200) NOT NULL,
    StudyProgram   VARCHAR(100) NOT NULL,
    EnrollmentYear INT          NOT NULL,
    PRIMARY KEY (Id)
) ENGINE = InnoDB;

-- Demo data (only if the table is empty)
INSERT INTO Students (FirstName, LastName, Email, StudyProgram, EnrollmentYear)
SELECT * FROM (
    SELECT 'Jonas' AS FirstName, 'Jonaitis' AS LastName, 'jonas@kk.lt' AS Email, 'Computer Science' AS StudyProgram, 2024 AS EnrollmentYear
    UNION ALL SELECT 'Ieva', 'Kazlauskaitė', 'ieva@kk.lt', 'Computer Science', 2024
    UNION ALL SELECT 'Amir', 'Haddad',       'amir@kk.lt', 'Software Systems', 2025
) AS seed
WHERE NOT EXISTS (SELECT 1 FROM Students);
