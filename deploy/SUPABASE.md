# Supabase database: automatic deployment to Test and Production

Lietuviškai: [SUPABASE_LT.md](SUPABASE_LT.md) · General deployment guide (Render, ghcr.io): [DEPLOYMENT.md](DEPLOYMENT.md)

The database structure lives **in git as migrations** (`supabase/migrations/*.sql`). GitHub Actions applies them to
the right Supabase project – nothing has to be run by hand in the SQL Editor any more.

| Git action | GitHub environment | Supabase project | Workflow |
|---|---|---|---|
| Pull request / push to `develop` (changing `supabase/`) | – | throw-away PostgreSQL in the GitHub runner | `check-migrations.yml` |
| push to `release/vX.Y.Z` | `test` | **SimpleStudent System Test** (`xkkzlqedgvztdlvgerbu`) | `deploy-test.yml` |
| `release/vX.Y.Z` → `main` + tag `vX.Y.Z` | `production` | **SimpleStudentSystem** (`ptkcvmldafnczhrixvcf`) | `deploy-production.yml` |

Order in both environments: **1) database** (migrations + demo data) → **2) Docker images** → Render.
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
