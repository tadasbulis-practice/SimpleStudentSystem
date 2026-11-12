<?php
declare(strict_types=1);

defined('APP_ROOT') || exit('No direct access.');

/*
 * SimpleStudentPhpApi – configuration
 *
 * 1. Choose the database with 'driver':
 *      'mysql'  – MySQL / MariaDB (XAMPP)                 needs PHP extension pdo_mysql  (XAMPP has it)
 *      'sqlsrv' – Microsoft SQL Server (Docker container) needs PHP extension pdo_sqlsrv (Docker image has it)
 * 2. Fill in the connection settings for that driver below.
 *
 * Every value can also be set with an environment variable (Docker uses this – see docker-compose.yml),
 * so you normally edit this file only for XAMPP.
 */

$env = static fn(string $name, string $default): string => (getenv($name) !== false && getenv($name) !== '') ? getenv($name) : $default;

return [
    'database' => [
        'driver' => $env('DB_DRIVER', 'mysql'),           // 'mysql' or 'sqlsrv'

        'mysql' => [                                       // XAMPP defaults: user root, empty password
            'host'     => $env('DB_HOST', '127.0.0.1'),
            'port'     => $env('DB_PORT', '3306'),
            'database' => $env('DB_NAME', 'StudentDb'),
            'user'     => $env('DB_USER', 'root'),
            'password' => $env('DB_PASSWORD', ''),
        ],

        'sqlsrv' => [                                      // the SQL Server container from docker-compose.infra.yml
            'host'     => $env('DB_HOST', 'localhost'),    // inside Docker: mssqlserver
            'port'     => $env('DB_PORT', '1433'),
            'database' => $env('DB_NAME', 'StudentDb'),
            'user'     => $env('DB_USER', 'sa'),
            'password' => $env('DB_PASSWORD', '1Secure*Password1'),
        ],
    ],

    // Shown in GET /api/info
    'environment' => $env('APP_ENVIRONMENT', 'Development'),

    // true  – error responses include the database message (handy while learning)
    // false – only a generic message (use this when the API is public)
    'debug' => $env('APP_DEBUG', 'true') === 'true',
];
