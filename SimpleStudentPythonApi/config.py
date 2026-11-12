"""
SimpleStudentPythonApi – configuration

1. Choose the database with DB_DRIVER:
     mysql   – MySQL / MariaDB (XAMPP)                   driver package: PyMySQL
     sqlsrv  – Microsoft SQL Server (Docker container)   driver package: pymssql
     sqlite  – a local file (students.db), no database server needed – handy for a first try
2. Fill in the connection settings for that driver.

Every value comes from an environment variable (Docker uses this – see docker-compose.yml).
The defaults below match XAMPP, exactly like config.php in SimpleStudentPhpApi,
so you normally change nothing when you run the API next to XAMPP.
The variable names are the same as in the PHP API.
"""

import os


def env(name: str, default: str) -> str:
    """Value of an environment variable, or the default when it is missing or empty."""
    value = os.getenv(name)
    return value if value else default


DB_DRIVER = env("DB_DRIVER", "mysql")            # 'mysql', 'sqlsrv' or 'sqlite'

# Default port and user depend on the database
_DEFAULTS = {
    "mysql":  {"host": "127.0.0.1", "port": "3306", "user": "root", "password": ""},
    "sqlsrv": {"host": "localhost", "port": "1433", "user": "sa",   "password": "1Secure*Password1"},
    "sqlite": {"host": "",          "port": "",     "user": "",     "password": ""},
}
_d = _DEFAULTS.get(DB_DRIVER, _DEFAULTS["mysql"])

DB_HOST     = env("DB_HOST", _d["host"])          # inside Docker: mssqlserver
DB_PORT     = env("DB_PORT", _d["port"])
DB_NAME     = env("DB_NAME", "StudentDb")
DB_USER     = env("DB_USER", _d["user"])
DB_PASSWORD = env("DB_PASSWORD", _d["password"])
SQLITE_FILE = env("SQLITE_FILE", "students.db")   # used only when DB_DRIVER=sqlite

# Shown in GET /api/info
APP_ENVIRONMENT = env("APP_ENVIRONMENT", "Development")

# true  – error responses include the database message (handy while learning)
# false – only a generic message (use this when the API is public)
APP_DEBUG = env("APP_DEBUG", "true").lower() == "true"
