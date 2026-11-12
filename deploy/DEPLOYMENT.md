# Deploying SimpleStudent to the cloud: Test and Production environments

Lietuviškai: [DEPLOYMENT_LT.md](DEPLOYMENT_LT.md)

This guide shows how the same code is deployed automatically to two environments following **classic gitflow**:

| Git action | Environment | Image tags | Workflow |
|---|---|---|---|
| push to `release/vX.Y.Z` | **Test** | `X.Y.Z-rc.<n>` and `test` | `deploy-test.yml` |
| `release/vX.Y.Z` merged into `main` + tag `vX.Y.Z` | **Production** | `X.Y.Z` and `latest` | `deploy-production.yml` |

**Live chain for the lecture:** Node.js API + Supabase PostgreSQL + PHP frontend, Test and Production.
The other chains (.NET API, PHP API, Python API, .NET frontend, MSSQL) use the same workflows and the same idea –
see [section 7](#7-other-chains-net-php-python-mssql).

---

## 1. What runs where, and why

```
                      GitHub (code + Actions)
                               │  docker build → push
                               ▼
                 GitHub Container Registry (ghcr.io)
                 simplestudentsystem-nodeapi:1.3.0-rc.4 / :test / 1.3.0 / :latest
                               │  deploy hook (imgURL=...)
              ┌────────────────┴────────────────┐
              ▼  TEST                           ▼  PRODUCTION
   Render: simplestudent-phpfrontend-test       Render: simplestudent-phpfrontend-prod
     API_BASE_URL ──┐                   API_BASE_URL ──┐
                    ▼                                  ▼
   Render: simplestudent-nodeapi-test           Render: simplestudent-nodeapi-prod
     DATABASE_URL ──┐                   DATABASE_URL ──┐
                    ▼                                  ▼
   Supabase: simplestudent-test       Supabase: simplestudent-prod
   (PostgreSQL)                       (PostgreSQL)
```

| Platform | Used for | Cost |
|---|---|---|
| **Supabase** | PostgreSQL databases (Test and Prod – two projects) | free: 2 active projects |
| **Render** | Docker containers: APIs and frontends | free: 750 h/month per workspace |
| **GitHub Container Registry** | Docker images | free for public packages |
| **GitHub Actions** | build + deploy | free for public repositories |
| **Azure** (next week) | Azure SQL (MSSQL) + Container Apps | Azure for Students: no credit card |

**Why not everything on Supabase?** Supabase is PostgreSQL as a service (+ Auth, Storage, Edge Functions in Deno/TypeScript).
It **cannot run your own Docker container**, so the .NET / PHP / Python / Node.js APIs and the frontends run elsewhere
(Render, Azure) and Supabase hosts the database. Supabase has no MSSQL either – that is what Azure SQL is for.

**The key principle – "build once, deploy many":** the same image goes to Test and to Production.
The environments differ **only in settings** (environment variables in Render): which database, which API URL.
The code knows nothing about the environment.

---

## 2. Once: the workflows in the GitHub repository

Workflows must be in the **repository root**, folder `.github/workflows/`. The lab keeps them in
`deploy/github-workflows/` so they can be copied into any repository.

```bash
cd PSe-5
mkdir -p .github/workflows
cp deploy/github-workflows/*.yml .github/workflows/
```

If the lab lives in **another folder** of your repository, change `lab_dir:` in `deploy-test.yml` and
`deploy-production.yml` (both).

| File | What it does |
|---|---|
| `_build-and-deploy.yml` | shared part: Supabase migrations → images of 6 projects → ghcr.io → Render deploy hook |
| `check-migrations.yml` | checks the migrations in pull requests on a throw-away PostgreSQL |
| `deploy-test.yml` | runs on push to `release/**`; version taken from the branch name |
| `deploy-production.yml` | runs on tag `v*.*.*`; checks that the tag is on `main` |

A project is deployed only when its **secret** (e.g. `RENDER_HOOK_NODEAPI`) exists in the GitHub environment.
Without the secret the image is still built and pushed to ghcr.io – ready for a later deployment.

### GitHub Environments

Repository → **Settings → Environments → New environment**:

1. `test`
2. `production`, plus:
   - **Required reviewers** – add yourself: the Production deployment waits for your approval (a good demo for students;
     available for public repositories).
   - **Deployment branches and tags → Selected branches and tags → Add rule → Tag: `v*`** – Production can only be
     deployed from a release tag.

The secrets (deploy hooks) are added in step 5, once the Render services exist.

### Workflow permissions

Repository → **Settings → Actions → General → Workflow permissions → Read and write permissions** (lets `GITHUB_TOKEN`
push images to ghcr.io). In an organization this may also have to be allowed in the organization settings.

---

## 3. Once: Supabase databases (Test and Production)

> **In the SimpleStudentSystem repository the table is created automatically** – the migrations in `supabase/migrations` are applied by GitHub Actions (job "database"). The manual way below stays as a fallback / for learning. See **[SUPABASE.md](SUPABASE.md)**. Projects: Test – `SimpleStudent System Test` (`xkkzlqedgvztdlvgerbu`), Production – `SimpleStudentSystem` (`ptkcvmldafnczhrixvcf`).

1. https://supabase.com → **Start your project** → sign in with GitHub.
2. **New project** twice:

   | | Test | Production |
   |---|---|---|
   | Name | `simplestudent-test` | `simplestudent-prod` |
   | Database Password | generate and **save it** | another one, save it too |
   | Region | Central EU (Frankfurt) | Central EU (Frankfurt) |

3. In each project: **SQL Editor → New query** → paste the whole `database/postgres/create.sql` → **Run**.
   This creates the table `Students` with 3 demo students; **Table Editor** shows it.
   To see the difference later, rename one student in the Production project.
4. In each project: **Connect** (top) → **Connection String** → **Method: Session pooler** → copy the URI:

   ```
   postgresql://postgres.abcdefghijklmnop:[YOUR-PASSWORD]@aws-0-eu-central-1.pooler.supabase.com:5432/postgres
   ```

   Replace `[YOUR-PASSWORD]` with the project password. Characters `@ : / ? # %` in the password must be URL-encoded
   (e.g. `@` → `%40`) – easier to generate a password of letters and digits only.

**Why Session pooler and not Direct connection?** On the free plan the direct connection works only over IPv6, and
Render connects over IPv4. The session pooler (port 5432) works over IPv4 and suits long-running servers.

**Why does `create.sql` end with `ENABLE ROW LEVEL SECURITY`?** Supabase automatically publishes every table of the
`public` schema through its own REST API with a public "anon" key. RLS without any policy closes that door; our APIs
connect as the table owner (`postgres`), which RLS does not restrict.

> A free Supabase project is **paused after 7 days without activity**. Before the lecture open the project and click
> **Restore project** – it takes a few minutes.

---

## 4. Building the images for the first time

A Render service can be created from an image only when the image exists. So the first time we simply start a
release – without secrets the workflow builds and pushes the images but deploys nothing.

```bash
git checkout develop
git pull
git checkout -b release/v1.3.0
git push -u origin release/v1.3.0
```


GitHub → **Actions → deploy-test**: 6 green jobs. The images appear on the repository page, right side, under
**Packages**: `pse-5-nodeapi`, `pse-5-phpfrontend`, `pse-5-dotnetapi` …

### Make the packages public

By default organization packages are **private** – Render cannot pull them. For every package you deploy:

**Packages → package → Package settings → Danger Zone → Change visibility → Public.**

For the live chain two are enough: `…-nodeapi` and `…-phpfrontend`.
(Alternative for private packages: Render → Workspace Settings → Container Registry Credentials, a GitHub token with
`read:packages`.)

---

## 5. Once: Render services

https://render.com → sign in with GitHub. For each service: **New → Web Service → Existing Image**.

### 5.1 Node.js API (Test and Production)

| Field | Test | Production |
|---|---|---|
| Image URL | `ghcr.io/tadasbulis-practice/pse-5-nodeapi:test` | `ghcr.io/tadasbulis-practice/pse-5-nodeapi:latest` |
| Name | `pse5-nodeapi-test` | `pse5-nodeapi-prod` |
| Region | Frankfurt (EU Central) | Frankfurt (EU Central) |
| Instance Type | **Free** | **Free** |

The Production image `:latest` exists only after the first Production release (section 8). Until then create the
Production service with `:test` – the next deploy hook switches it to the exact version anyway.

**Environment Variables** (Add from .env – paste all at once):

```
DB_DRIVER=postgres
DB_SSL=true
DATABASE_URL=postgresql://postgres.xxxx:PASSWORD@aws-0-eu-central-1.pooler.supabase.com:5432/postgres
APP_ENVIRONMENT=Test
APP_DEBUG=true
PORT=8080
```

Production service: `DATABASE_URL` of **simplestudent-prod**, `APP_ENVIRONMENT=Production`, `APP_DEBUG=false`.

Then open `https://pse5-nodeapi-test.onrender.com/swagger` and `/api/info` – it shows `"environment": "Test"` and
version `1.3.0-rc.N`.

### 5.2 PHP frontend (Test and Production)

| Field | Test | Production |
|---|---|---|
| Image URL | `ghcr.io/tadasbulis-practice/pse-5-phpfrontend:test` | `ghcr.io/tadasbulis-practice/pse-5-phpfrontend:latest` |
| Name | `pse5-phpfrontend-test` | `pse5-phpfrontend-prod` |
| Instance Type | **Free** | **Free** |

```
API_BASE_URL=https://pse5-nodeapi-test.onrender.com
API_PUBLIC_URL=https://pse5-nodeapi-test.onrender.com
DOTNET_FRONTEND_URL=https://pse5-dotnetfrontend-test.onrender.com
PORT=80
```

Production: the same variables with the `-prod` addresses. **This is where the frontend's "base URL" points to the API
of its own environment** – same code, only these settings differ.

The exact service address is shown at the top of the Render service page (Render adds a suffix if the name is taken).

### 5.3 Deploy hooks → GitHub secrets

In each Render service **Settings → Deploy Hook** → copy the URL (`https://api.render.com/deploy/srv-...?key=...`).

GitHub → **Settings → Environments → test → Add environment secret**:

| Secret | Value |
|---|---|
| `RENDER_HOOK_NODEAPI` | deploy hook of `pse5-nodeapi-test` |
| `RENDER_HOOK_PHPFRONTEND` | deploy hook of `pse5-phpfrontend-test` |

The same in the **production** environment with the hooks of the `-prod` services.

A deploy hook is a secret: whoever knows it can redeploy the service. Database passwords are **not** stored in
GitHub – only in the Render settings.

---

## 6. How the workflow works (what to show students)

1. `deploy-test.yml` takes the version `1.3.0` from the branch `release/v1.3.0` and adds `-rc.<run number>`.
2. `_build-and-deploy.yml`, for every project (matrix):
   - `docker build` with `APP_VERSION=1.3.0-rc.4` (the Node API shows it in `/api/info`),
   - `docker push` to `ghcr.io/<owner>/<repo>-<project>` with two tags: `1.3.0-rc.4` and `test`,
   - if the secret exists – `curl` to the Render deploy hook with `imgURL=...:1.3.0-rc.4`.
3. Render pulls exactly that image and starts it with **its own** environment variables.
4. `deploy-production.yml` does the same for the tag `v1.3.0` → images `1.3.0` and `latest`, but only if the tag is on
   `main` and (if enabled) only after your approval.

The **Summary** of every Actions run shows a table: which project was built, which one deployed.

---

## 7. Other chains (.NET, PHP, Python, MSSQL)

All projects are already built by the workflow. To deploy one, create its Render service (section 5) and add its secret.

| Project | Secret | Render PORT | Environment variables (values differ for Test / Prod) |
|---|---|---|---|
| Node.js API | `RENDER_HOOK_NODEAPI` | 8080 | `DB_DRIVER=postgres`, `DB_SSL=true`, `DATABASE_URL` – or `DB_DRIVER=sqlsrv` + `DB_HOST` … Azure SQL |
| .NET API | `RENDER_HOOK_DOTNETAPI` | 8080 | `ConnectionStrings__DefaultConnection` (Azure SQL), `ASPNETCORE_ENVIRONMENT` |
| PHP API | `RENDER_HOOK_PHPAPI` | 80 | `DB_DRIVER=sqlsrv`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `APP_ENVIRONMENT` |
| Python API | `RENDER_HOOK_PYTHONAPI` | 8080 | the same `DB_*` as the PHP API |
| .NET frontend (Razor Pages) | `RENDER_HOOK_DOTNETFRONTEND` | 8080 | `ApiSettings__BaseUrl`, `ApiSettings__PublicUrl`, `ApiSettings__PhpFrontendUrl` |
| PHP frontend | `RENDER_HOOK_PHPFRONTEND` | 80 | `API_BASE_URL`, `API_PUBLIC_URL`, `DOTNET_FRONTEND_URL` |

Both frontends read the API address **at run time** from environment variables, so one image serves both
environments. (Blazor WebAssembly does not – its settings are in the static `wwwroot/appsettings.json`, so deploying it
needs an extra step; it is not covered here.)

**Which API can use which database today:**

| API | Supabase (PostgreSQL) | Azure SQL (MSSQL) |
|---|---|---|
| Node.js | ✔ | ✔ (`DB_SSL=true`) |
| .NET | – (needs the Npgsql package) | ✔ |
| PHP | – (needs the `pdo_pgsql` extension) | ✔ |
| Python | – (needs the `psycopg` package) | ✔ |

MSSQL in the cloud = **Azure SQL Database** (free offer: up to 10 databases, 100,000 vCore seconds per month each).
Test and Production are two separate databases. The Azure SQL chain is next week's topic; the workflows will not change,
only the Render (or Azure Container Apps) settings.

---

## 8. Demo: a release from start to finish

### 8.1 Release → Test

```bash
git checkout develop
git pull
git checkout -b release/v1.3.0
git push -u origin release/v1.3.0
```

Or with the git-flow tool (set "Version tag prefix" to `v` during `git flow init`):

```bash
git flow release start 1.3.0
git flow release publish 1.3.0
```

Check:

- GitHub → **Actions → deploy-test** – green,
- `https://pse5-nodeapi-test.onrender.com/api/info` → `"environment": "Test"`, `"version": "1.3.0-rc.N"`,
- `https://pse5-phpfrontend-test.onrender.com` → students from the **Test** database.

A fix on the release branch (e.g. a changed text) → commit → push → automatically a new `rc` in Test.

### 8.2 Finishing the release → Production

```bash
git checkout main
git pull
git merge --no-ff release/v1.3.0
git tag -a v1.3.0 -m "Release 1.3.0"
git push origin main v1.3.0
git checkout develop
git merge --no-ff v1.3.0
git push origin develop
git branch -d release/v1.3.0
git push origin --delete release/v1.3.0
```

Or with git-flow:

```bash
git flow release finish 1.3.0
git push origin main develop --tags
```

Check:

- GitHub → **Actions → deploy-production** → (if reviewers are enabled) **Review deployments → Approve**,
- `https://pse5-nodeapi-prod.onrender.com/api/info` → `"environment": "Production"`, `"version": "1.3.0"`,
- `https://pse5-phpfrontend-prod.onrender.com` → students from the **Production** database.

If pull requests are required for `main`, merge through a PR (`release/v1.3.0` → `main`), then create the tag on `main`
and push it with `git push origin v1.3.0`.

---

## 9. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| First page takes ~1 min, or the PHP frontend shows "Cannot reach the API" | A free Render service sleeps after 15 min. Before the lecture open `/api/info` of both environments, wait for the answer, then reload the frontend. |
| Render: `pull access denied` / `unauthorized` | The ghcr.io package is private – section 4, "Change visibility → Public". |
| Deploy hook: `400 Bad Request` | The Render service's Image URL differs from the workflow's image (e.g. another repository / owner). Everything except the tag after `:` must match. |
| `/api/info` works, `/api/students` → 500 "Database error" | Check `DATABASE_URL` (Session pooler, password, `DB_SSL=true`). The Supabase project may be paused. |
| `ENETUNREACH` / `getaddrinfo` with `db.xxxx.supabase.co` | Direct connection (IPv6) is used. Use the Session pooler URI. |
| `deploy-production`: "not on main" | The tag was created on the release branch commit before the merge. Delete the tag and create it on `main`. |
| `deploy-test`: "not release/vX.Y.Z" | The branch must be named `release/v1.3.0` or `release/1.3.0`. |
| Actions: `denied: installation not allowed to Write organization package` | Settings → Actions → General → Workflow permissions → Read and write (section 2). |
| Render "No open ports detected" | Missing `PORT` variable (Node/.NET/Python: 8080, PHP: 80). |

---

## 10. Next week: Azure

- **Azure SQL Database** (free offer) – Test and Production MSSQL databases; `database/…/create.sql` in the Query editor.
- **Azure Container Apps** – the same ghcr.io images; the workflow gets `az containerapp update --image ...` next to the
  deploy hook step (login with `azure/login`, OIDC).
- PostgreSQL support for the PHP / Python / .NET APIs, so every API can use Supabase.
