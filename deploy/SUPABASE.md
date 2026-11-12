# Supabase database: automatic deployment to Test and Production

Lietuviškai: [SUPABASE_LT.md](SUPABASE_LT.md) · General deployment guide (Render, ghcr.io): [DEPLOYMENT.md](DEPLOYMENT.md)

The database structure lives **in git as migrations** (`supabase/migrations/*.sql`). GitHub Actions applies them to
the right Supabase project – nothing has to be run by hand in the SQL Editor any more.

| Git action | GitHub environment | Supabase project | Workflow |
|---|---|---|---|
| Pull request / push to `develop` (changing `supabase/`) | – | throw-away PostgreSQL in the GitHub runner | `check-migrations.yml` |
| push to `release/vX.Y.Z` | `test` | **SimpleStudent System Test** (`xkkzlqedgvztdlvgerbu`) | `deploy-test.yml` |
| `release/vX.Y.Z` → `main` + tag `vX.Y.Z` | `production` | **SimpleStudentSystem** (`ptkcvmldafnczhrixvcf`) | `deploy-production.yml` |

Order in both environments: **1) database** (migrations + demo data) → **2) the API inside Supabase**
(Edge Function, [section 6](#6-the-api-inside-supabase-edge-function-simplestudent-api)) and **Docker images** → Render.
New code therefore never runs against an old table.

---

## 1. What is in the repository

```
supabase/
├── config.toml                                   <- from `supabase init` (local Supabase, CLI settings)
├── migrations/
│   └── 20261112000000_create_students.sql        <- table "Students" + Row Level Security
└── seed.sql                                      <- 3 demo students (only if the table is empty)
database/postgres/create.sql                      <- the same table for the local Docker PostgreSQL
.github/workflows/
├── _build-and-deploy.yml                         <- job "database" (supabase db push) → job "image" (Docker + Render)
├── deploy-test.yml                               <- release/** → environment "test"
├── deploy-production.yml                         <- tag v*.*.* on main → environment "production"
└── check-migrations.yml                          <- checks migrations in pull requests (no passwords needed)
```

A **migration** is an SQL file with a timestamp in its name. Supabase records applied files in
`supabase_migrations.schema_migrations`, so every file runs **only once** per database.
Never edit an applied migration – every change is a new file.

**Seed** (`seed.sql`) – demo data. `supabase db push --include-seed` runs it once (and again only when the file
changes). `WHERE NOT EXISTS` makes sure nothing is inserted into a table that already has data.

---

## 2. One time: GitHub settings (lecturer)

### 2.1 Environments

Repository → **Settings → Environments → New environment**:

1. `test`
2. `production`, additionally:
   - **Required reviewers** → add yourself (the production deployment waits for approval),
   - **Deployment branches and tags → Selected branches and tags → Tag: `v*`**.

### 2.2 Secrets and variables

In each environment: **Environment secrets → Add secret** and **Environment variables → Add variable**.

| Environment | Type | Name | Value |
|---|---|---|---|
| `test` | secret | `SUPABASE_DB_URL` | `postgresql://postgres.xkkzlqedgvztdlvgerbu:PASSWORD@aws-0-eu-central-1.pooler.supabase.com:5432/postgres` |
| `test` | variable | `SUPABASE_PROJECT_REF` | `xkkzlqedgvztdlvgerbu` |
| `production` | secret | `SUPABASE_DB_URL` | `postgresql://postgres.ptkcvmldafnczhrixvcf:PASSWORD@aws-1-eu-west-1.pooler.supabase.com:5432/postgres` |
| `production` | variable | `SUPABASE_PROJECT_REF` | `ptkcvmldafnczhrixvcf` |

`PASSWORD` is the project's **Database password** (Supabase → Project Settings → Database). Characters
`@ : / ? # %` must be URL-encoded (`@` → `%40`).

**Passwords never go into the repository** – only into GitHub secrets (and Render settings). Nobody can read a
secret's value, not even a repository admin; logs mask it automatically (`***`).

Without the secret the "database" job is skipped with a notice – the images are still built.

### 2.3 Why the Session pooler and not the Direct connection?

`db.<ref>.supabase.co` (Direct connection) is **IPv6 only** on the free plan, while GitHub Actions runners and
Render have IPv4 only. The **Session pooler** (`aws-…pooler.supabase.com:5432`, user `postgres.<ref>`) works over
IPv4 and supports everything migrations need. CI and the APIs both use the Session pooler URI.

### 2.4 First run when the table already exists

If `create.sql` was already run by hand in the SQL Editor, nothing to do: the migration uses
`CREATE TABLE IF NOT EXISTS`, and the seed inserts nothing into a non-empty table. After the first `db push`
Supabase simply records the migration as applied.

---

## 3. Daily work: a new migration (student / team)

Install the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started)
(`brew install supabase/tap/supabase`, Windows: `scoop install supabase`, or `npx supabase …`).

```bash
git checkout develop && git pull
git checkout -b feature/student-phone

supabase migration new add_phone_to_students
# → creates supabase/migrations/<timestamp>_add_phone_to_students.sql
```

In the file:

```sql
ALTER TABLE "Students" ADD COLUMN IF NOT EXISTS "Phone" varchar(30);
```

Test it locally (either way):

```bash
# a) the local Docker PostgreSQL from docker-compose.postgres.yml
supabase db push --remote="postgresql://postgres:1Secure*Password1@localhost:5432/StudentDb" --include-seed --yes

# b) the full local Supabase stack (Docker; Studio at http://localhost:54323)
supabase start
supabase db reset          # all migrations + seed.sql from scratch
```

Then `git add supabase/ && git commit && git push` → pull request into `develop` → **check-migrations** must be green.
Remember to update the APIs too (model, Swagger contract) and `database/postgres/create.sql` for local Docker.

### What you see during a release

- **Actions → deploy-test → Supabase database (test)** – the log shows `Applying migration …_add_phone_to_students.sql…`,
  the **Summary** lists the migrations and links to the Table Editor.
- Supabase **Table Editor** (Test project) – the new column. Production does not have it yet – only after the
  `vX.Y.Z` tag on `main`.

### Preview without changing anything

```bash
supabase db push --remote="<Session pooler URI>" --include-seed --dry-run
```

---

## 4. Your own copy (for students)

The repository is public: students can read it, but cannot change it and cannot see the secrets. To get your own
working version:

1. **Fork** (or **Use this template**) into your GitHub account.
2. Supabase → two free projects (Test, Production) → copy the Session pooler URI of each.
3. In your repository: environments `test` and `production` from section 2, secrets `SUPABASE_DB_URL`, variables
   `SUPABASE_PROJECT_REF`. Settings → Actions → General → Workflow permissions → **Read and write**.
4. `git checkout -b release/v0.1.0 && git push -u origin release/v0.1.0` → your Test database is created automatically.

---

## 5. Common problems

| Symptom | Cause / fix |
|---|---|
| `failed to connect … db.xxxx.supabase.co` / `network is unreachable` | Direct connection (IPv6) is used. The secret must hold the **Session pooler** URI. |
| `password authentication failed for user "postgres"` | The pooler user is `postgres.<project-ref>`, not `postgres`; or the password is wrong / not URL-encoded. |
| `Tenant or user not found` | Wrong region in the pooler host (Test: `aws-0-eu-central-1`, Prod: `aws-1-eu-west-1`) – copy the URI from the **Connect** dialog. |
| Job finishes, nothing changes / connection timeout | Project paused after 7 days of inactivity → Supabase dashboard → **Restore project**. |
| `Remote migration versions not found in local migrations directory` | The database has a migration the repository no longer has (file deleted / renamed). Restore the file; as a last resort `supabase migration repair --status reverted <version>`. |
| Edited an applied migration, database does not change | Expected – a migration runs once. Create a new migration. |
| "No secret SUPABASE_DB_URL" | The secret was created at repository level or in another environment – it must be an **Environment secret** of `test` / `production`. |

---

## 6. The API inside Supabase: Edge Function `simplestudent-api`

Supabase cannot run our Docker containers, but it has **Edge Functions**: server code in TypeScript/JavaScript
running on **Deno** (Node.js npm packages are imported with `npm:`). Free plan: 500,000 invocations per month.
Python, PHP and .NET do not run there, so Supabase gets the **Node.js API** version: the same Express code, the same
`openapi.json` contract, the same validator.

| | Node.js API (Docker → Render) | Edge Function API (Supabase) |
|---|---|---|
| Code | `SimpleStudentNodeApi/src/app.js` | `supabase/functions/simplestudent-api/index.ts` |
| Runs as | Node.js container, always on | Deno, started per request (serverless) |
| Database | `DATABASE_URL` (Session pooler) | `SUPABASE_DB_URL` – provided by Supabase |
| Deployment | Docker image → ghcr.io → Render deploy hook | `supabase functions deploy` |
| Swagger UI | `/swagger` (HTML) | **GitHub Pages** – Edge Functions cannot return HTML |

**Addresses** (after a release):

| | Test | Production |
|---|---|---|
| API | `https://xkkzlqedgvztdlvgerbu.supabase.co/functions/v1/simplestudent-api/api/students` | `https://ptkcvmldafnczhrixvcf.supabase.co/functions/v1/simplestudent-api/api/students` |
| Info | `…/simplestudent-api/api/info` | `…/simplestudent-api/api/info` |
| Contract | `…/simplestudent-api/swagger/v1/swagger.json` | `…/simplestudent-api/swagger/v1/swagger.json` |
| Swagger UI | `https://tadasbulis-practice.github.io/SimpleStudentSystem/?env=test` | `https://tadasbulis-practice.github.io/SimpleStudentSystem/?env=production` |

### 6.1 One time: settings

1. **Supabase access token** (for deploying the function; the DB password is not enough):
   supabase.com → avatar top right → **Account preferences → Access Tokens → Generate new token**
   (e.g. `github-actions-SimpleStudentSystem`). One token works for both projects.
2. **GitHub secret** – one for the whole repository:
   ```bash
   gh secret set SUPABASE_ACCESS_TOKEN --repo tadasbulis-practice/SimpleStudentSystem
   ```
   (it asks for the value, so it does not end up in your shell history).
3. **Production read-only** (recommended – the API is public, without login):
   ```bash
   gh variable set API_READ_ONLY --env production --repo tadasbulis-practice/SimpleStudentSystem --body true
   ```
   In Test, POST / PUT / DELETE work – students can experiment. In Production they answer `403`.
4. **GitHub Pages:** Settings → **Pages → Build and deployment → Source: GitHub Actions**.
   The page (`swagger-ui/index.html`) is published whenever `main` changes (= every Production release)
   or with Actions → **pages → Run workflow**.

### 6.2 What the workflow does

Job **Supabase Edge Function API** in `_build-and-deploy.yml` (after the migrations):

1. `supabase secrets set` – settings of the function: `APP_ENVIRONMENT` (Test / Production), `APP_VERSION`
   (e.g. `1.1.0-rc.3`), `API_READ_ONLY`, `SWAGGER_UI_URL`;
2. `supabase functions deploy simplestudent-api --use-api --no-verify-jwt` – Supabase bundles and deploys it;
3. **smoke test**: `GET /api/info` must return exactly this version, `GET /api/students` the list of students.

Without `SUPABASE_ACCESS_TOKEN` the job is skipped with a notice. In pull requests `check-migrations.yml` also checks
that the function compiles (`deno check`, `deno lint`) and that its copies of `openapi.json`, `validator.js` and
`problems.js` are **identical** to `SimpleStudentNodeApi` – one contract for all APIs.

`verify_jwt = false` (`supabase/config.toml`) – the API is called without the Supabase key, like the Render APIs.

### 6.3 Locally (Supabase CLI + Docker)

```bash
supabase start
supabase functions serve
```

Then `http://localhost:54321/functions/v1/simplestudent-api/api/students`. The function uses the local Supabase
database (`supabase db reset` creates the table and demo data).

Changed the contract `SimpleStudentNodeApi/openapi/openapi.json`? Copy it into the function too:

```bash
cp SimpleStudentNodeApi/openapi/openapi.json SimpleStudentNodeApi/src/validator.js SimpleStudentNodeApi/src/problems.js supabase/functions/simplestudent-api/
```

### 6.4 Problems

| Symptom | Cause / fix |
|---|---|
| `Unauthorized` / `401` while deploying | `SUPABASE_ACCESS_TOKEN` wrong or revoked – generate a new one. |
| Smoke test: version does not match | The function still runs with the old secrets – re-run the job. |
| `/swagger` in the browser shows JSON | Expected: Edge Functions cannot return HTML. Open Swagger UI on GitHub Pages. |
| Swagger UI: "API not reachable" | Function not deployed to that project yet, or the project is paused. |
| `403 This environment is read-only` | `API_READ_ONLY=true` in this environment – use Test. |
| `500 Database error` | The table is missing (migrations not applied) – see job "Supabase database". |
