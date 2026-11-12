/*
 * Microsoft SQL Server – npm package "mssql" (uses "tedious", pure JavaScript).
 * Works with the mssqlserver Docker container and with Azure SQL Database (DB_SSL=true).
 *
 * Parameters are written as @name and passed with request.input(...) – never glue user input into SQL.
 */

import sql from 'mssql';
import { config } from '../config.js';
import { toJson } from './mapping.js';

const settings = (database) => ({
    server:   config.db.host,
    port:     config.db.port,
    database,
    user:     config.db.user,
    password: config.db.password,
    options: {
        encrypt: config.db.ssl,            // Azure SQL requires encryption; the local container does not
        trustServerCertificate: true,      // the container uses a self-signed certificate
    },
    pool: { max: 10 },
});

let pool = null;

async function getPool() {
    if (!pool) pool = await new sql.ConnectionPool(settings(config.db.name)).connect();
    return pool;
}

/** Creates the database (if missing) and the table Students – like EnsureCreated() in the .NET API. */
export async function prepare() {
    try {
        await getPool();
    } catch (err) {
        pool = null;
        // ELOGIN = the server answered but refused the login. One reason: the database StudentDb
        // does not exist yet ("Cannot open database ..."). Then create it through the database "master".
        // (SQL Server still starting, wrong host → ESOCKET / ETIMEOUT → simply try again later.)
        if (err.code !== 'ELOGIN') throw err;
        if (!/^[A-Za-z0-9_]+$/.test(config.db.name)) throw new Error(`Invalid DB_NAME '${config.db.name}'`);

        let master;
        try {
            master = await new sql.ConnectionPool(settings('master')).connect();
        } catch {
            throw err;          // no access to master (e.g. Azure SQL user) → show the original error
        }
        await master.request().query(`IF DB_ID('${config.db.name}') IS NULL CREATE DATABASE [${config.db.name}]`);
        await master.close();
        await getPool();
    }

    await (await getPool()).request().query(`
        IF OBJECT_ID('dbo.Students', 'U') IS NULL
        CREATE TABLE dbo.Students (
            Id             INT           IDENTITY(1,1) NOT NULL PRIMARY KEY,
            FirstName      NVARCHAR(100) NOT NULL,
            LastName       NVARCHAR(100) NOT NULL,
            Email          NVARCHAR(200) NOT NULL,
            StudyProgram   NVARCHAR(100) NOT NULL,
            EnrollmentYear INT           NOT NULL
        )`);
}

/** request with the five student fields as parameters @FirstName ... @EnrollmentYear */
async function studentRequest(s) {
    return (await getPool()).request()
        .input('FirstName',      sql.NVarChar(100), s.firstName)
        .input('LastName',       sql.NVarChar(100), s.lastName)
        .input('Email',          sql.NVarChar(200), s.email)
        .input('StudyProgram',   sql.NVarChar(100), s.studyProgram)
        .input('EnrollmentYear', sql.Int,           s.enrollmentYear);
}

export async function all() {
    const result = await (await getPool()).request().query('SELECT * FROM dbo.Students ORDER BY Id');
    return result.recordset.map(toJson);
}

export async function find(id) {
    const result = await (await getPool()).request()
        .input('Id', sql.Int, id)
        .query('SELECT * FROM dbo.Students WHERE Id = @Id');
    return result.recordset[0] ? toJson(result.recordset[0]) : null;
}

export async function create(s) {
    const result = await (await studentRequest(s)).query(`
        INSERT INTO dbo.Students (FirstName, LastName, Email, StudyProgram, EnrollmentYear)
        OUTPUT INSERTED.*
        VALUES (@FirstName, @LastName, @Email, @StudyProgram, @EnrollmentYear)`);
    return toJson(result.recordset[0]);
}

export async function update(id, s) {
    const result = await (await studentRequest(s)).input('Id', sql.Int, id).query(`
        UPDATE dbo.Students
        SET FirstName = @FirstName, LastName = @LastName, Email = @Email,
            StudyProgram = @StudyProgram, EnrollmentYear = @EnrollmentYear
        OUTPUT INSERTED.*
        WHERE Id = @Id`);
    return result.recordset[0] ? toJson(result.recordset[0]) : null;
}

export async function remove(id) {
    const result = await (await getPool()).request()
        .input('Id', sql.Int, id)
        .query('DELETE FROM dbo.Students WHERE Id = @Id');
    return result.rowsAffected[0] > 0;
}
