# SimpleStudentPythonApi

**Tas pats Students REST API**, kaip `SimpleStudentApi` (.NET) ir `SimpleStudentPhpApi`: tie patys URL,
tas pats JSON, tie patys būsenos kodai, tas pats `swagger.json`. Parašyta su **Python 3.10+** ir **FastAPI**.
Galima naudoti tris duomenų bazes:

| `DB_DRIVER` | Duomenų bazė | Tipinė aplinka | Python paketas |
|---|---|---|---|
| `mysql`  | MySQL / MariaDB | **XAMPP** (numatytoji) | `PyMySQL` |
| `sqlsrv` | Microsoft SQL Server | **Docker** (`mssqlserver` konteineris) | `pymssql` (Docker image'e; lokaliai `requirements-mssql.txt`) |
| `sqlite` | vietinis failas `students.db` | greitas išbandymas be DB serverio | įdiegtas Python'e |

Kadangi visi trys API laikosi vieno kontrakto, **bet kuris frontend'as veikia su bet kuriuo API**: keičiamas tik URL.
English: [README.md](README.md).

```
SimpleStudentPythonApi/
├── main.py            ← programa: maršrutai /api/..., /swagger, swagger.json pataisos
├── models.py          ← Pydantic modeliai = KONTRAKTAS (laukai, required, maxLength, min/max)
├── database.py        ← SQLAlchemy: lentelės aprašas + visas SQL (veikia su visomis DB)
├── problems.py        ← klaidų atsakymai .NET formatu (400 / 404 / 500 problem details)
├── config.py          ← DB NUSTATYMAI (iš aplinkos kintamųjų, numatytosios reikšmės XAMPP'ui)
├── requirements.txt   ← Python paketai (MySQL + SQLite)
├── requirements-mssql.txt ← + pymssql SQL Server'iui (jį naudoja Docker image)
├── swagger-ui/        ← Swagger UI failai (įtraukti – internetas nereikalingas)
└── Dockerfile
```

## Endpoint'ai

| Metodas | URL | Atsakymai | operationId |
|---|---|---|---|
| GET | `/api/info` | 200 | `GetInfo` |
| GET | `/api/students` | 200 | `GetStudents` |
| GET | `/api/students/{id}` | 200, 404 | `GetStudent` |
| POST | `/api/students` | 201, 400 | `CreateStudent` |
| PUT | `/api/students/{id}` | 200, 400, 404 | `UpdateStudent` |
| DELETE | `/api/students/{id}` | 204, 404 | `DeleteStudent` |
| GET | `/api/faculty` | 200 | `GetFaculty` |
| GET | `/swagger` · `/swagger/v1/swagger.json` | Swagger UI · kontraktas | |

## 1. Paleidimas lokaliai (šalia XAMPP)

XAMPP vykdo PHP Apache viduje, bet **ne Python**. Python API yra atskiras mažas web serveris
(uvicorn). Duomenų bazė vis tiek naudojama XAMPP'o **MySQL**.

1. Įdiekite **Python 3.10 ar naujesnį** (https://www.python.org/downloads/ – Windows'e pažymėkite *Add python.exe to PATH*).
2. XAMPP Control Panel'yje paleiskite **MySQL** ir vieną kartą sukurkite duomenų bazę:
   phpMyAdmin → **Import** → `../SimpleStudentPhpApi/database/mysql/create.sql` → **Go**.
3. Terminale, šiame aplanke:

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

4. Atidarykite **http://localhost:6003/swagger**.

Numatytosios reikšmės `config.py` faile atitinka XAMPP (`mysql`, `127.0.0.1:3306`, vartotojas `root`, tuščias slaptažodis).
Kitą kartą užtenka `source .venv/bin/activate` (Windows: `.venv\Scripts\Activate.ps1`) ir `python main.py`.

**Neturite XAMPP?** Naudokite SQLite: failas ir trys demonstraciniai studentai sukuriami automatiškai:

```bash
DB_DRIVER=sqlite python main.py
```

PowerShell: `$env:DB_DRIVER="sqlite"`, tada `python main.py`.

## 2. Docker + SQL Server

Iš aplanko `student-docker-lab-plus-mssql`:

```bash
docker-compose -f docker-compose.infra.yml up -d
docker-compose up --build
```

Atidarykite **http://localhost:6003/swagger**. Nustatymai imami iš `docker-compose.yml`
(`DB_DRIVER=sqlsrv`, `DB_HOST=mssqlserver`). Jei `Students` lentelės nėra, API ją sukuria
(kaip `EnsureCreated()` .NET'e); duomenų bazę `StudentDb` paleidžiamas sukuria .NET API.

.NET, PHP ir Python API dabar **naudoja vieną lentelę**: viename sukurtas studentas matomas ir kituose.

## 3. Kiti deriniai

| Kur veikia API | Duomenų bazė | Nustatymai |
|---|---|---|
| lokaliai (`python main.py`) | MySQL (XAMPP) | numatytieji |
| lokaliai | SQLite failas | `DB_DRIVER=sqlite` |
| lokaliai | SQL Server konteineris | `pip install -r requirements-mssql.txt`, tada `DB_DRIVER=sqlsrv` (host `localhost`, user `sa` yra numatytieji) |
| Docker | SQL Server konteineris | numatytieji `docker-compose.yml` faile |
| Docker | jūsų kompiuterio XAMPP MySQL | `docker-compose.yml`: `DB_DRIVER: mysql`, `DB_HOST: host.docker.internal`, vartotojas iš `create-user.sql` |

Visi nustatymai yra aplinkos kintamieji, tais pačiais pavadinimais kaip PHP API:
`DB_DRIVER`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `APP_ENVIRONMENT`, `APP_DEBUG`,
taip pat `SQLITE_FILE` ir `PORT` (vietinis prievadas, numatytasis 6003).

## Frontend'ų prijungimas prie šio API

| Frontend'as | Nustatymas |
|---|---|
| .NET frontend'as (Docker) | `ApiSettings__BaseUrl: http://simplestudentpythonapi:8080` faile `docker-compose.yml` |
| PHP frontend'as (Docker) | `API_BASE_URL: http://simplestudentpythonapi:8080` faile `docker-compose.yml` |
| PHP frontend'as (XAMPP) | `apiBaseUrl` faile `SimpleStudentPhpFrontend/config.php` → `http://localhost:6003` |
| .NET frontend'as (dotnet run) | `ApiSettings:BaseUrl` faile `appsettings.Development.json` → `http://localhost:6003` |
| Flutter programa | `flutter run --dart-define=API_BASE_URL=http://localhost:6003` (Android emuliatorius: `http://10.0.2.2:6003`) |

Kodo keisti nereikia: Python API realizuoja lygiai tą kontraktą, pagal kurį sukurti klientai.

## Trys keliai į tą patį kontraktą

| | .NET API | PHP API | Python API |
|---|---|---|---|
| Iš kur kontraktas | generuojamas iš C# klasių (Swashbuckle) | rašomas ranka: `openapi/openapi.json` | generuojamas iš Pydantic modelių (FastAPI) |
| Validacijos taisyklės | C# atributai + validatorius | skaitomos iš kontrakto | Pydantic `Field(...)` + validatoriai |
| Klaidų formatas | integruotas (ValidationProblem) | `Http.php` | `problems.py` (FastAPI numatytasis 422 pakeistas į 400) |
| OpenAPI versija | 3.0 | 3.0 | 3.1 |

Ką FastAPI pagal nutylėjimą daro kitaip ir kaip `main.py` / `problems.py` tai suderina su .NET:

| FastAPI numatytasis | .NET kontraktas | Kur pakeista |
|---|---|---|
| validacijos klaida **422** `{"detail": [...]}` | **400** problem details su `errors` kiekvienam laukui | `problems.py` |
| laukų vardai `first_name` | `firstName` (camelCase) | `models.py` (alias generator) |
| Swagger ties `/docs`, kontraktas ties `/openapi.json` | `/swagger`, `/swagger/v1/swagger.json` | `main.py` |
| Swagger UI kraunamas iš CDN | įtraukti failai | `main.py` + `swagger-ui/` |
| `/api/students/abc` → 422 | 404 (maršrutas `{id:int}` nesutampa) | `problems.py` |

## Problemų sprendimas

| Problema | Sprendimas |
|---|---|
| `python: command not found` | macOS/Linux: naudokite `python3`; Windows: perinstaliuokite Python su *Add to PATH* |
| `ModuleNotFoundError: fastapi` | neaktyvuota virtuali aplinka – `source .venv/bin/activate` |
| "DB_DRIVER=sqlsrv needs the package pymssql" | `pip install -r requirements-mssql.txt` |
| 500 "Database error … Access denied" | `DB_USER` / `DB_PASSWORD` |
| 500 "Database error … Unknown database 'StudentDb'" | importuokite `../SimpleStudentPhpApi/database/mysql/create.sql` |
| Paleidžiant rodoma "DB not ready yet" | XAMPP MySQL arba SQL Server konteineris nepaleistas |
| Prievadas 6003 užimtas | `PORT=6004 python main.py` |
| Nustatykite `APP_DEBUG=false` | klaidų atsakymuose nebus DB detalių |
