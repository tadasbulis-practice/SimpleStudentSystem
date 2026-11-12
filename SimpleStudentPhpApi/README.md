# SimpleStudentPhpApi

The **same Students REST API** as `SimpleStudentApi` (.NET) — same URLs, same JSON, same status
codes, same `swagger.json` — written in plain **PHP 8.1+**. It can use two databases:

| `driver` in config.php | Database | Typical setup | PHP extension |
|---|---|---|---|
| `mysql`  | MySQL / MariaDB | **XAMPP** | `pdo_mysql` (included in XAMPP) |
| `sqlsrv` | Microsoft SQL Server | **Docker** (`mssqlserver` container) | `pdo_sqlsrv` (included in the Docker image) |

Because both APIs follow one contract, **both frontends work with either API** — change only the URL.

```
SimpleStudentPhpApi/            ← flat folder: copy it as it is to XAMPP htdocs
├── index.php                   ← front controller: routes /api/... and /swagger
├── config.php                  ← DATABASE SETTINGS (driver, host, port, user, password)
├── openapi/openapi.json        ← the contract (same as the .NET swagger.json)
├── lib/
│   ├── Database.php            ← PDO connection for mysql or sqlsrv
│   ├── StudentRepository.php   ← all SQL (standard SQL – works on both databases)
│   ├── Validator.php           ← validates requests using the rules in openapi.json
│   ├── Http.php                ← JSON responses, problem details, routing, CORS
│   └── swagger-ui.php          ← Swagger UI page
├── swagger-ui/                 ← Swagger UI files (bundled – no internet needed)
├── database/
│   ├── mysql/create.sql        ← creates StudentDb + Students + demo data (XAMPP)
│   ├── mysql/create-user.sql   ← optional: separate MySQL user instead of root
│   └── mssql/create.sql        ← the same for SQL Server
├── .htaccess                   ← pretty URLs (/api/students) + blocks config.php, lib/, database/
└── Dockerfile
```

## Endpoints

| Method | URL | Responses |
|---|---|---|
| GET | `/api/info` | 200 |
| GET | `/api/students` | 200 |
| GET | `/api/students/{id}` | 200, 404 |
| POST | `/api/students` | 201, 400 |
| PUT | `/api/students/{id}` | 200, 400, 404 |
| DELETE | `/api/students/{id}` | 204, 404 |
| GET | `/api/faculty` | 200 |
| GET | `/swagger` · `/swagger/v1/swagger.json` | Swagger UI · contract |

## 1. XAMPP + MySQL

1. Start **Apache** and **MySQL** in the XAMPP Control Panel.
2. Create the database: phpMyAdmin (http://localhost/phpmyadmin) → **Import** → `database/mysql/create.sql` → **Go**.
   (or in a terminal: `mysql -u root < database/mysql/create.sql`)
3. Copy this folder to `htdocs/simpleStudentApi`.
4. Check `config.php` — the defaults match XAMPP (`driver` `mysql`, host `127.0.0.1`, user `root`, empty password).
5. Open **http://localhost/simpleStudentApi/swagger** (add `:8080` if your Apache uses that port).

> **No mod_rewrite?** Use URLs with `index.php`: http://localhost/simpleStudentApi/index.php/swagger,
> `.../index.php/api/students`. The API detects this and builds its links accordingly.
>
> **macOS, 403 Forbidden:** `chmod -R a+rX /Applications/XAMPP/xamppfiles/htdocs/simpleStudentApi`

## 2. Docker + SQL Server

```bash
docker-compose -f docker-compose.infra.yml up -d     # SQL Server
docker-compose up --build                            # .NET API, both frontends, PHP API
```

Open **http://localhost:6002/swagger**. The settings come from `docker-compose.yml`
(`DB_DRIVER=sqlsrv`, `DB_HOST=mssqlserver`). The .NET API creates the database and table on
start-up; if you run the PHP API alone, use `database/mssql/create.sql`:

```bash
docker cp database/mssql/create.sql mssqlserver:/tmp/create.sql
docker exec mssqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "1Secure*Password1" -No -f 65001 -i /tmp/create.sql
```

The .NET API and the PHP API now **share one table**: a student created in one appears in the other.

## 3. Other combinations

| API runs in | Database | Settings |
|---|---|---|
| XAMPP | MySQL (XAMPP) | defaults in `config.php` |
| Docker | SQL Server container | defaults in `docker-compose.yml` |
| Docker | MySQL of XAMPP on your computer | in `docker-compose.yml`: `DB_DRIVER: mysql`, `DB_HOST: host.docker.internal`, user from `create-user.sql` |
| XAMPP | SQL Server container | `driver` `sqlsrv`, host `localhost` — needs the [Microsoft Drivers for PHP for SQL Server](https://learn.microsoft.com/sql/connect/php/download-drivers-php-sql-server) in XAMPP (Windows) |
| `php -S localhost:6002 index.php` | either | edit `config.php` |

Every setting in `config.php` can also be given as an environment variable:
`DB_DRIVER`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `APP_ENVIRONMENT`, `APP_DEBUG`.

## Connect the frontends to this API

| Frontend | Setting |
|---|---|
| PHP frontend | `apiBaseUrl` in `SimpleStudentPhpFrontend/config.php`, e.g. `http://localhost/simpleStudentApi` |
| .NET frontend (Docker) | `ApiSettings__BaseUrl: http://simplestudentphpapi` in `docker-compose.yml` |
| .NET frontend (dotnet run) | `ApiSettings:BaseUrl` in `appsettings.Development.json`, e.g. `http://localhost:6002` |

No code changes are needed — the .NET frontend's generated client works unchanged, because the
PHP API implements exactly the contract the client was generated from.

## Code-first vs contract-first

| | .NET API | PHP API |
|---|---|---|
| Where the contract comes from | generated from C# code (Swashbuckle) | written by hand: `openapi/openapi.json` |
| Validation rules | C# attributes + validator | read from the contract (`Validator.php`) |
| Change a rule | change C#, swagger.json follows | change openapi.json, validation follows |

## Troubleshooting

| Problem | Fix |
|---|---|
| 500 "Database error … Access denied" | user/password in `config.php` |
| 500 "Database error … Unknown database / Invalid object name 'Students'" | run `database/<driver>/create.sql` |
| 500 "PHP extension pdo_sqlsrv is not installed" | use `mysql` in XAMPP, or the Docker image for SQL Server |
| 404 for `/api/students` in XAMPP | mod_rewrite is off – use `/index.php/api/students` |
| Lithuanian letters broken after import | import the `.sql` file as UTF-8 (phpMyAdmin default) |
| Set `APP_DEBUG=false` | error responses then hide database details |
