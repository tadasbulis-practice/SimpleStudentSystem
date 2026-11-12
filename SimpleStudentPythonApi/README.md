# SimpleStudentPythonApi

The **same Students REST API** as `SimpleStudentApi` (.NET) and `SimpleStudentPhpApi` — same URLs,
same JSON, same status codes, same `swagger.json` — written in **Python 3.10+** with **FastAPI**.
It can use three databases:

| `DB_DRIVER` | Database | Typical setup | Python package |
|---|---|---|---|
| `mysql`  | MySQL / MariaDB | **XAMPP** (default) | `PyMySQL` |
| `sqlsrv` | Microsoft SQL Server | **Docker** (`mssqlserver` container) | `pymssql` (in the Docker image; locally `requirements-mssql.txt`) |
| `sqlite` | a local file `students.db` | quick first try, no database server | built into Python |

Because all three APIs follow one contract, **every frontend works with every API** — change only the URL.
Lietuviškai: [README_LT.md](README_LT.md).

```
SimpleStudentPythonApi/
├── main.py            ← the app: routes /api/..., /swagger, swagger.json fixes
├── models.py          ← Pydantic models = THE CONTRACT (fields, required, maxLength, min/max)
├── database.py        ← SQLAlchemy: table definition + all SQL (works on every database)
├── problems.py        ← error responses in the .NET format (400 / 404 / 500 problem details)
├── config.py          ← DATABASE SETTINGS (read from environment variables, XAMPP defaults)
├── requirements.txt   ← Python packages (MySQL + SQLite)
├── requirements-mssql.txt ← + pymssql for SQL Server (the Docker image uses this one)
├── swagger-ui/        ← Swagger UI files (bundled – no internet needed)
└── Dockerfile
```

## Endpoints

| Method | URL | Responses | operationId |
|---|---|---|---|
| GET | `/api/info` | 200 | `GetInfo` |
| GET | `/api/students` | 200 | `GetStudents` |
| GET | `/api/students/{id}` | 200, 404 | `GetStudent` |
| POST | `/api/students` | 201, 400 | `CreateStudent` |
| PUT | `/api/students/{id}` | 200, 400, 404 | `UpdateStudent` |
| DELETE | `/api/students/{id}` | 204, 404 | `DeleteStudent` |
| GET | `/api/faculty` | 200 | `GetFaculty` |
| GET | `/swagger` · `/swagger/v1/swagger.json` | Swagger UI · contract | |

## 1. Run locally (next to XAMPP)

XAMPP runs PHP inside Apache, but **not Python** — a Python API is its own small web server
(uvicorn). You still use XAMPP's **MySQL**.

1. Install **Python 3.10 or newer** (https://www.python.org/downloads/ – on Windows tick *Add python.exe to PATH*).
2. Start **MySQL** in the XAMPP Control Panel and create the database once:
   phpMyAdmin → **Import** → `../SimpleStudentPhpApi/database/mysql/create.sql` → **Go**.
3. In a terminal, in this folder:

macOS / Linux:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python main.py
```

Windows (PowerShell):

```powershell
py -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python main.py
```

4. Open **http://localhost:6003/swagger**.

The defaults in `config.py` match XAMPP (`mysql`, `127.0.0.1:3306`, user `root`, empty password).
Next time only `source .venv/bin/activate` (Windows: `.venv\Scripts\Activate.ps1`) and `python main.py` are needed.

**No XAMPP at all?** Use SQLite — the file and three demo students are created automatically:

```bash
DB_DRIVER=sqlite python main.py
```

PowerShell: `$env:DB_DRIVER="sqlite"` and then `python main.py`.

## 2. Docker + SQL Server

From the folder `student-docker-lab-plus-mssql`:

```bash
docker-compose -f docker-compose.infra.yml up -d
docker-compose up --build
```

Open **http://localhost:6003/swagger**. The settings come from `docker-compose.yml`
(`DB_DRIVER=sqlsrv`, `DB_HOST=mssqlserver`). The API creates the `Students` table if it is missing
(like `EnsureCreated()` in .NET); the database `StudentDb` is created by the .NET API on start-up.

The .NET, PHP and Python APIs now **share one table**: a student created in one appears in the others.

## 3. Other combinations

| API runs | Database | Settings |
|---|---|---|
| locally (`python main.py`) | MySQL (XAMPP) | defaults |
| locally | SQLite file | `DB_DRIVER=sqlite` |
| locally | SQL Server container | `pip install -r requirements-mssql.txt`, then `DB_DRIVER=sqlsrv` (host `localhost`, user `sa` are the defaults) |
| Docker | SQL Server container | defaults in `docker-compose.yml` |
| Docker | MySQL of XAMPP on your computer | in `docker-compose.yml`: `DB_DRIVER: mysql`, `DB_HOST: host.docker.internal`, user from `create-user.sql` |

All settings are environment variables — the same names as in the PHP API:
`DB_DRIVER`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `APP_ENVIRONMENT`, `APP_DEBUG`,
plus `SQLITE_FILE` and `PORT` (local port, default 6003).

## Connect the frontends to this API

| Frontend | Setting |
|---|---|
| .NET frontend (Docker) | `ApiSettings__BaseUrl: http://simplestudentpythonapi:8080` in `docker-compose.yml` |
| PHP frontend (Docker) | `API_BASE_URL: http://simplestudentpythonapi:8080` in `docker-compose.yml` |
| PHP frontend (XAMPP) | `apiBaseUrl` in `SimpleStudentPhpFrontend/config.php` → `http://localhost:6003` |
| .NET frontend (dotnet run) | `ApiSettings:BaseUrl` in `appsettings.Development.json` → `http://localhost:6003` |
| Flutter app | `flutter run --dart-define=API_BASE_URL=http://localhost:6003` (Android emulator: `http://10.0.2.2:6003`) |

No code changes are needed: the Python API implements exactly the contract the clients were built from.

## Three ways to the same contract

| | .NET API | PHP API | Python API |
|---|---|---|---|
| Where the contract comes from | generated from C# classes (Swashbuckle) | written by hand: `openapi/openapi.json` | generated from Pydantic models (FastAPI) |
| Validation rules | C# attributes + validator | read from the contract | Pydantic `Field(...)` + validators |
| Error format | built in (ValidationProblem) | `Http.php` | `problems.py` (FastAPI default is 422 – replaced by 400) |
| OpenAPI version | 3.0 | 3.0 | 3.1 |

What FastAPI does differently by default — and how `main.py` / `problems.py` make it match .NET:

| FastAPI default | .NET contract | Changed in |
|---|---|---|
| validation error **422** `{"detail": [...]}` | **400** problem details with `errors` per field | `problems.py` |
| field names `first_name` | `firstName` (camelCase) | `models.py` (alias generator) |
| Swagger at `/docs`, contract at `/openapi.json` | `/swagger`, `/swagger/v1/swagger.json` | `main.py` |
| Swagger UI loaded from a CDN | bundled files | `main.py` + `swagger-ui/` |
| `/api/students/abc` → 422 | 404 (route `{id:int}` does not match) | `problems.py` |

## Troubleshooting

| Problem | Fix |
|---|---|
| `python: command not found` | macOS/Linux: use `python3`; Windows: reinstall Python with *Add to PATH* |
| `ModuleNotFoundError: fastapi` | the virtual environment is not active – `source .venv/bin/activate` |
| "DB_DRIVER=sqlsrv needs the package pymssql" | `pip install -r requirements-mssql.txt` |
| 500 "Database error … Access denied" | `DB_USER` / `DB_PASSWORD` |
| 500 "Database error … Unknown database 'StudentDb'" | import `../SimpleStudentPhpApi/database/mysql/create.sql` |
| "DB not ready yet" at start-up | MySQL in XAMPP / the SQL Server container is not running |
| Port 6003 is busy | `PORT=6004 python main.py` |
| Set `APP_DEBUG=false` | error responses then hide database details |
