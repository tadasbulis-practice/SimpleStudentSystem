/*
 * SimpleStudentNodeApi – configuration
 *
 * 1. Choose the database with DB_DRIVER:
 *      sqlsrv    – Microsoft SQL Server (the mssqlserver Docker container, Azure SQL)   npm package: mssql
 *      postgres  – PostgreSQL (the postgres Docker container, Supabase)                  npm package: pg
 * 2. Fill in the connection settings for that driver.
 *
 * Every value comes from an environment variable:
 *   - Docker / Render / Azure:  set in docker-compose.yml or in the hosting dashboard
 *   - npm start on your computer: copy .env.example to .env and edit it
 * The variable names are the same as in the PHP and Python APIs.
 */

import 'dotenv/config';

/** Value of an environment variable, or the default when it is missing or empty. */
const env = (name, fallback) => {
    const value = process.env[name];
    return value !== undefined && value !== '' ? value : fallback;
};

const driver = env('DB_DRIVER', 'sqlsrv');

// Default port and user depend on the database (same defaults as the Docker containers of the lab)
const DEFAULTS = {
    sqlsrv:   { host: 'localhost', port: '1433', user: 'sa',       password: '1Secure*Password1' },
    postgres: { host: 'localhost', port: '5432', user: 'postgres', password: '1Secure*Password1' },
};
const d = DEFAULTS[driver] ?? DEFAULTS.sqlsrv;

export const config = {
    port: Number(env('PORT', '6004')),             // Docker sets 8080, Render sets its own PORT
    host: env('HOST', '0.0.0.0'),

    db: {
        driver,                                    // 'sqlsrv' or 'postgres'
        host:     env('DB_HOST', d.host),          // inside Docker: mssqlserver / postgres
        port:     Number(env('DB_PORT', d.port)),
        name:     env('DB_NAME', 'StudentDb'),     // Supabase: postgres
        user:     env('DB_USER', d.user),
        password: env('DB_PASSWORD', d.password),
        ssl:      env('DB_SSL', 'false') === 'true',   // true for Supabase and Azure SQL
        url:      env('DATABASE_URL', ''),         // PostgreSQL only: one connection string instead of DB_HOST ... DB_PASSWORD
    },

    // Shown in GET /api/info
    environment: env('APP_ENVIRONMENT', 'Development'),   // Development / Docker / Test / Production
    version:     env('APP_VERSION', '1.2'),               // set by the CI/CD pipeline to the release version

    // true  – error responses include the database message (handy while learning)
    // false – only a generic message (use this when the API is public)
    debug: env('APP_DEBUG', 'true') === 'true',
};
