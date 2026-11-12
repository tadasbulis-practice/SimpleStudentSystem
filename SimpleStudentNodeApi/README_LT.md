# SimpleStudentNodeApi – Node.js + Express

**Tas pats Students REST API** kaip `SimpleStudentApi` (.NET), `SimpleStudentPhpApi` ir `SimpleStudentPythonApi` –
tie patys endpointai, tas pats JSON, tas pats klaidų formatas, tas pats `swagger.json` adresas. Bet kuris
laboratorinio darbo frontendas veikia su juo, pakeitus tik API adresą.

| | |
|---|---|
| Kalba / karkasas | Node.js 18+ (Docker: 22 LTS), Express 5 |
| Kontraktas | `openapi/openapi.json` – rašytas ranka (**contract-first**, kaip PHP API) |
| Swagger UI | `/swagger` (paketas `swagger-ui-express`), kontraktas `/swagger/v1/swagger.json` |
| Duomenų bazės | **SQL Server** (`mssql`) arba **PostgreSQL** (`pg`) – pasirenkama su `DB_DRIVER` |
| Portai | `npm start`: **6004** · Docker: **6004** (SQL Server) ir **6005** (PostgreSQL) |

English: [README.md](README.md)

---

## Projekto struktūra

```
SimpleStudentNodeApi/
├── package.json          <- priklausomybės + "npm start"
├── .env.example          <- nukopijuok į .env, kai leidi su npm start (DB_DRIVER, DB_HOST ...)
├── Dockerfile            <- node:22-alpine, klauso 8080 porto
├── openapi/openapi.json  <- KONTRAKTAS: jį rodo Swagger UI, iš jo taisykles skaito validator.js
└── src/
    ├── server.js         <- paleidimas: paruošti DB → klausyti porto
    ├── app.js            <- Express programa: Swagger UI + visi endpointai + klaidų apdorojimas
    ├── config.js         <- visi nustatymai iš aplinkos kintamųjų
    ├── validator.js      <- užklausų tikrinimas pagal openapi.json
    ├── problems.js       <- RFC 9457 problem+json klaidos (kaip ASP.NET Core)
    └── db/
        ├── index.js      <- pagal DB_DRIVER pasirenka sqlsrv.js arba postgres.js, kartoja jungimąsi
        ├── sqlsrv.js     <- SQL Server: @parametrai, OUTPUT INSERTED.*
        ├── postgres.js   <- PostgreSQL: $1 parametrai, RETURNING *, "KabutėseRašomiVardai"
        └── mapping.js    <- stulpelių vardai (FirstName) ↔ JSON laukai (firstName)
```

---

## 1. Paleidimas su npm (savarankiškai, pasirinktame porte, API be Docker)

Reikia **Node.js 18 ar naujesnio** (`node -v`) ir veikiančios duomenų bazės.

```bash
cd SimpleStudentNodeApi
npm install
cp .env.example .env
npm start
```

Windows (cmd): `copy .env.example .env`

Atidaryk **http://localhost:6004/swagger**.

Duomenų bazė:

| `.env` | Duomenų bazė | Kaip paleisti |
|---|---|---|
| `DB_DRIVER=sqlsrv` (numatyta) | SQL Server konteineris, `localhost:1433` | `docker-compose -f docker-compose.infra.yml up -d` |
| `DB_DRIVER=postgres` + `DB_PORT=5432` + `DB_USER=postgres` | PostgreSQL konteineris, `localhost:5432` | `docker-compose -f docker-compose.postgres.yml up -d` |
| `DB_DRIVER=postgres` + `DB_SSL=true` + `DATABASE_URL=...` | Supabase (debesis) | žr. `deploy/DEPLOYMENT_LT.md` |

Kitas portas: `.env` faile `PORT=7000`. Automatinis perkrovimas po kiekvieno kodo pakeitimo: `npm run dev`.

Paleidžiamas API sukuria lentelę `Students`, jei jos nėra (kaip `EnsureCreated()` .NET'e); su SQL Server
sukuria ir duomenų bazę `StudentDb`. Jei DB nepasiekiama, API ~30 s bando iš naujo, o tada vis tiek
pasileidžia – užklausos grąžina **500** su patarimu.

## 2. Paleidimas Docker'yje

Iš laboratorinio aplanko (kur yra `docker-compose.yml`):

```bash
docker-compose -f docker-compose.infra.yml up -d
docker-compose -f docker-compose.postgres.yml up -d --build
docker-compose up --build simplestudentnodeapi simplestudentnodeapi-pg
```

| Konteineris | Duomenų bazė | Swagger |
|---|---|---|
| `simplestudentnodeapi` | SQL Server (`mssqlserver`) – ta pati lentelė kaip .NET, PHP ir Python API | http://localhost:6004/swagger |
| `simplestudentnodeapi-pg` | PostgreSQL (`postgres`) | http://localhost:6005/swagger |

**Vienas image'as, dvi konfigūracijos** – palygink abu servisus `docker-compose.yml` faile: skiriasi tik
`DB_*` kintamieji. Lygiai taip debesyje veikia Test ir Production aplinkos (žr. `deploy/DEPLOYMENT_LT.md`).

## 3. Nustatymai (aplinkos kintamieji)

| Kintamasis | Numatyta | Reikšmė |
|---|---|---|
| `DB_DRIVER` | `sqlsrv` | `sqlsrv` arba `postgres` |
| `DB_HOST` | `localhost` | Docker: `mssqlserver` / `postgres` |
| `DB_PORT` | `1433` / `5432` | |
| `DB_NAME` | `StudentDb` | Supabase: `postgres` |
| `DB_USER` | `sa` / `postgres` | |
| `DB_PASSWORD` | `1Secure*Password1` | |
| `DB_SSL` | `false` | `true` Supabase ir Azure SQL atveju |
| `DATABASE_URL` | – | tik PostgreSQL: viena prisijungimo eilutė vietoj `DB_HOST` … `DB_PASSWORD` |
| `PORT` | `6004` | Docker image'e: `8080` |
| `APP_ENVIRONMENT` | `Development` | rodoma `/api/info` (`Docker`, `Test`, `Production` …) |
| `APP_VERSION` | `1.2` | rodoma `/api/info`; CI/CD nustato release versiją |
| `APP_DEBUG` | `true` | `false` – slepia DB klaidų detales (viešose aplinkose) |

## 4. Endpointai

| Metodas | Maršrutas | operationId |
|---|---|---|
| GET | `/api/info` | GetInfo |
| GET | `/api/students` | GetStudents |
| GET | `/api/students/{id}` | GetStudent |
| POST | `/api/students` | CreateStudent |
| PUT | `/api/students/{id}` | UpdateStudent |
| DELETE | `/api/students/{id}` | DeleteStudent |
| GET | `/api/faculty` | GetFaculty |

Neteisingi duomenys → **400** `application/problem+json` su laukų klaidomis, tie patys pranešimai kaip .NET API:

```json
{ "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "One or more validation errors occurred.", "status": 400,
  "errors": { "email": ["A valid email is required."] } }
```

## 5. Naudojimas iš frontendų

| Frontendas | Nustatymas |
|---|---|
| .NET Razor Pages | `ApiSettings__BaseUrl=http://simplestudentnodeapi:8080` (Docker) arba `http://localhost:6004` |
| PHP frontendas | `API_BASE_URL=http://simplestudentnodeapi:8080` arba `apiBaseUrl` faile `config.php` (XAMPP: `http://localhost:6004`) |
| Blazor Server / WebAssembly | jau yra API perjungiklyje: *Node.js (SQL Server)*, *Node.js (PostgreSQL)* |

## 6. Contract-first ir code-first

| API | Kas parašo `swagger.json`? |
|---|---|
| .NET, Python | sugeneruojamas iš kodo (C# atributai, Pydantic modeliai) – **code-first** |
| PHP, **Node.js** | rašomas ranka, kodas jo laikosi – **contract-first** |

`validator.js` iš `components.schemas.Student` skaito `required`, `maxLength`, `format: email`,
`minimum`/`maximum` ir `readOnly`. Išbandyk: `firstName` lauke pakeisk `"maxLength": 100` į `10`, perkrauk –
pasikeis ir Swagger UI, ir validacija, nors JavaScript kodo neliesi.

## 7. SQL Server ir PostgreSQL – į ką atkreipti dėmesį

| | SQL Server (`sqlsrv.js`) | PostgreSQL (`postgres.js`) |
|---|---|---|
| Parametrai | `@FirstName` + `request.input(...)` | `$1, $2 …` + reikšmių masyvas |
| Automatinis ID | `IDENTITY(1,1)` | `GENERATED BY DEFAULT AS IDENTITY` |
| Grąžinti naują eilutę | `OUTPUT INSERTED.*` | `RETURNING *` |
| Vardai | `Students`, `FirstName` (didžiosios/mažosios nesvarbu) | `"Students"`, `"FirstName"` – kabutės išlaiko didžiąsias raides |
| Unicode tekstas | `NVARCHAR` | `varchar` / `text` visada Unicode |
| Šifruotas ryšys | `options.encrypt` | `ssl` |
