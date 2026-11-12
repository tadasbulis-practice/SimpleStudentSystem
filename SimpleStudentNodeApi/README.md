# SimpleStudentNodeApi – Node.js + Express

The **same Students REST API** as `SimpleStudentApi` (.NET), `SimpleStudentPhpApi` and `SimpleStudentPythonApi` –
same endpoints, same JSON, same error format, same `swagger.json` URL. Any frontend of the lab works with it
by changing only its API address.

| | |
|---|---|
| Language / framework | Node.js 18+ (Docker: 22 LTS), Express 5 |
| Contract | `openapi/openapi.json` – written by hand (**contract-first**, like the PHP API) |
| Swagger UI | `/swagger` (package `swagger-ui-express`), contract at `/swagger/v1/swagger.json` |
| Databases | **SQL Server** (`mssql`) or **PostgreSQL** (`pg`) – chosen with `DB_DRIVER` |
| Ports | `npm start`: **6004** · Docker: **6004** (SQL Server) and **6005** (PostgreSQL) |

Lietuviškai: [README_LT.md](README_LT.md)

---

## Project structure

```
SimpleStudentNodeApi/
├── package.json          <- dependencies + "npm start"
├── .env.example          <- copy to .env for npm start (DB_DRIVER, DB_HOST ...)
├── Dockerfile            <- node:22-alpine, listens on 8080
├── openapi/openapi.json  <- THE CONTRACT: Swagger UI shows it, validator.js reads its rules
└── src/
    ├── server.js         <- start-up: prepare database → listen
    ├── app.js            <- Express app: Swagger UI + all endpoints + error handling
    ├── config.js         <- every setting from environment variables
    ├── validator.js      <- request validation driven by openapi.json
    ├── problems.js       <- RFC 9457 problem+json errors (same as ASP.NET Core)
    └── db/
        ├── index.js      <- picks sqlsrv.js or postgres.js by DB_DRIVER, retries on start-up
        ├── sqlsrv.js     <- SQL Server: @parameters, OUTPUT INSERTED.*
        ├── postgres.js   <- PostgreSQL: $1 parameters, RETURNING *, "QuotedNames"
        └── mapping.js    <- column names (FirstName) ↔ JSON fields (firstName)
```

---

## 1. Run with npm (self-hosted on a port, no Docker for the API)

Needs **Node.js 18 or newer** (`node -v`) and a running database.

```bash
cd SimpleStudentNodeApi
npm install
cp .env.example .env
npm start
```

Windows (cmd): `copy .env.example .env`

Open **http://localhost:6004/swagger**.

The database:

| `.env` | Database | Start it with |
|---|---|---|
| `DB_DRIVER=sqlsrv` (default) | SQL Server container, `localhost:1433` | `docker-compose -f docker-compose.infra.yml up -d` |
| `DB_DRIVER=postgres` + `DB_PORT=5432` + `DB_USER=postgres` | PostgreSQL container, `localhost:5432` | `docker-compose -f docker-compose.postgres.yml up -d` |
| `DB_DRIVER=postgres` + `DB_SSL=true` + `DATABASE_URL=...` | Supabase (cloud) | see `deploy/DEPLOYMENT.md` |

Other port: `PORT=7000` in `.env`. Restart automatically after every code change: `npm run dev`.

On start-up the API creates the table `Students` if it is missing (like `EnsureCreated()` in .NET);
with SQL Server it also creates the database `StudentDb`. If the database is not reachable the API
retries for ~30 s and then starts anyway – requests answer **500** with a hint.

## 2. Run in Docker

From the lab folder (where `docker-compose.yml` is):

```bash
docker-compose -f docker-compose.infra.yml up -d
docker-compose -f docker-compose.postgres.yml up -d --build
docker-compose up --build simplestudentnodeapi simplestudentnodeapi-pg
```

| Container | Database | Swagger |
|---|---|---|
| `simplestudentnodeapi` | SQL Server (`mssqlserver`) – same table as the .NET, PHP and Python APIs | http://localhost:6004/swagger |
| `simplestudentnodeapi-pg` | PostgreSQL (`postgres`) | http://localhost:6005/swagger |

**One image, two configurations** – compare the two services in `docker-compose.yml`: only the `DB_*`
variables differ. That is exactly how Test and Production work in the cloud (see `deploy/DEPLOYMENT.md`).

## 3. Settings (environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `DB_DRIVER` | `sqlsrv` | `sqlsrv` or `postgres` |
| `DB_HOST` | `localhost` | Docker: `mssqlserver` / `postgres` |
| `DB_PORT` | `1433` / `5432` | |
| `DB_NAME` | `StudentDb` | Supabase: `postgres` |
| `DB_USER` | `sa` / `postgres` | |
| `DB_PASSWORD` | `1Secure*Password1` | |
| `DB_SSL` | `false` | `true` for Supabase and Azure SQL |
| `DATABASE_URL` | – | PostgreSQL only: one connection string instead of `DB_HOST` … `DB_PASSWORD` |
| `PORT` | `6004` | Docker image: `8080` |
| `APP_ENVIRONMENT` | `Development` | shown in `/api/info` (`Docker`, `Test`, `Production` …) |
| `APP_VERSION` | `1.2` | shown in `/api/info`; the CI/CD pipeline sets the release version |
| `APP_DEBUG` | `true` | `false` hides database error details (use in public environments) |

## 4. Endpoints

| Method | Route | operationId |
|---|---|---|
| GET | `/api/info` | GetInfo |
| GET | `/api/students` | GetStudents |
| GET | `/api/students/{id}` | GetStudent |
| POST | `/api/students` | CreateStudent |
| PUT | `/api/students/{id}` | UpdateStudent |
| DELETE | `/api/students/{id}` | DeleteStudent |
| GET | `/api/faculty` | GetFaculty |

Invalid input → **400** `application/problem+json` with field errors, the same messages as the .NET API:

```json
{ "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "One or more validation errors occurred.", "status": 400,
  "errors": { "email": ["A valid email is required."] } }
```

## 5. Use it from the frontends

| Frontend | Setting |
|---|---|
| .NET Razor Pages | `ApiSettings__BaseUrl=http://simplestudentnodeapi:8080` (Docker) or `http://localhost:6004` |
| PHP frontend | `API_BASE_URL=http://simplestudentnodeapi:8080` or `apiBaseUrl` in `config.php` (XAMPP: `http://localhost:6004`) |
| Blazor Server / WebAssembly | already in the API switcher: *Node.js (SQL Server)*, *Node.js (PostgreSQL)* |

## 6. Contract-first vs code-first

| API | Who writes `swagger.json`? |
|---|---|
| .NET, Python | generated from the code (C# attributes, Pydantic models) – **code-first** |
| PHP, **Node.js** | written by hand, the code follows it – **contract-first** |

`validator.js` reads `required`, `maxLength`, `format: email`, `minimum`/`maximum` and `readOnly` from
`components.schemas.Student`. Try it: change `"maxLength": 100` of `firstName` to `10`, restart –
both Swagger UI and the validation change, no JavaScript edited.

## 7. SQL Server vs PostgreSQL – what students should notice

| | SQL Server (`sqlsrv.js`) | PostgreSQL (`postgres.js`) |
|---|---|---|
| Parameters | `@FirstName` + `request.input(...)` | `$1, $2 …` + array of values |
| Auto ID | `IDENTITY(1,1)` | `GENERATED BY DEFAULT AS IDENTITY` |
| Get the new row | `OUTPUT INSERTED.*` | `RETURNING *` |
| Names | `Students`, `FirstName` (case-insensitive) | `"Students"`, `"FirstName"` – quotes keep the capitals |
| Unicode text | `NVARCHAR` | `varchar` / `text` are always Unicode |
| Encrypted connection | `options.encrypt` | `ssl` |
