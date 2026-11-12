<?php
declare(strict_types=1);

defined('APP_ROOT') || exit('No direct access.');

/**
 * Creates a PDO connection for the driver chosen in config.php.
 * PDO gives one PHP API for many databases – only the DSN (connection string) differs.
 */
final class Database
{
    public const DRIVERS = ['mysql', 'sqlsrv'];

    public static function connect(array $dbConfig): PDO
    {
        $driver = $dbConfig['driver'];
        if (!in_array($driver, self::DRIVERS, true)) {
            throw new RuntimeException("Unknown database driver '$driver'. Use 'mysql' or 'sqlsrv' in config.php.");
        }
        if (!extension_loaded("pdo_$driver")) {
            throw new RuntimeException("PHP extension pdo_$driver is not installed. "
                . ($driver === 'sqlsrv'
                    ? 'Use the Docker image, or install the Microsoft Drivers for PHP for SQL Server.'
                    : 'Enable extension=pdo_mysql in php.ini.'));
        }

        $c = $dbConfig[$driver];
        $dsn = match ($driver) {
            // MySQL / MariaDB
            'mysql'  => "mysql:host={$c['host']};port={$c['port']};dbname={$c['database']};charset=utf8mb4",
            // Microsoft SQL Server. TrustServerCertificate: the Docker container uses a self-signed certificate.
            'sqlsrv' => "sqlsrv:Server={$c['host']},{$c['port']};Database={$c['database']};TrustServerCertificate=1",
        };

        return new PDO($dsn, $c['user'], $c['password'], [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
    }
}
