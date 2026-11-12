/*
 * Database layer – one interface, two implementations:
 *
 *   sqlsrv.js    Microsoft SQL Server  (npm package mssql – pure JavaScript, no system driver needed)
 *   postgres.js  PostgreSQL            (npm package pg)
 *
 * Both use the table and column names the .NET API (EF Core) creates – "Students" with
 * Id, FirstName, LastName, Email, StudyProgram, EnrollmentYear – so all APIs can share one table.
 * Compare the two files: the SQL is almost the same, the differences are the interesting part
 * (parameters @name vs $1, IDENTITY vs GENERATED ... AS IDENTITY, OUTPUT INSERTED vs RETURNING).
 */

import { config } from '../config.js';

const drivers = {
    sqlsrv:   () => import('./sqlsrv.js'),
    postgres: () => import('./postgres.js'),
};

if (!drivers[config.db.driver]) {
    throw new Error(`Unknown DB_DRIVER '${config.db.driver}'. Use sqlsrv or postgres.`);
}

/** @type {{ prepare(): Promise<void>, all(): Promise<object[]>, find(id): Promise<object|null>,
 *           create(s): Promise<object>, update(id, s): Promise<object|null>, remove(id): Promise<boolean> }} */
export const db = await drivers[config.db.driver]();

/** Waits for the database (SQL Server in Docker needs ~20 s to start) – like EnsureCreated() with retries in .NET. */
export async function prepareWithRetry(retries = 10, delayMs = 3000) {
    for (let attempt = 1; attempt <= retries; attempt++) {
        try {
            await db.prepare();
            console.log('Database ready.');
            return;
        } catch (err) {
            console.log(`DB not ready yet (attempt ${attempt}/${retries}): ${err.message}`);
            if (attempt < retries) await new Promise((r) => setTimeout(r, delayMs));
        }
    }
    // The API still starts: every request that needs the database answers 500 with a hint.
    console.log('Database is not reachable – the API starts anyway, check the DB_* settings.');
}
