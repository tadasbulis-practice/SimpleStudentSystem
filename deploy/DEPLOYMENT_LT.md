# SimpleStudent diegimas į debesį: Test ir Production aplinkos

English: [DEPLOYMENT.md](DEPLOYMENT.md)

Šis gidas parodo, kaip tą patį kodą automatiškai išdiegti į dvi aplinkas pagal **klasikinį gitflow**:

| Git veiksmas | Aplinka | Image'o žymė (tag) | Workflow |
|---|---|---|---|
| push į `release/vX.Y.Z` | **Test** | `X.Y.Z-rc.<nr>` ir `test` | `deploy-test.yml` |
| `release/vX.Y.Z` sumerginamas į `main` + žymė `vX.Y.Z` | **Production** | `X.Y.Z` ir `latest` | `deploy-production.yml` |

**Rytdienos gyva grandinė:** Node.js API + Supabase PostgreSQL + PHP frontendas, Test ir Production.
Kitos grandinės (.NET API, PHP API, Python API, .NET frontendas, MSSQL) naudoja tuos pačius workflow'us ir
tą patį principą – žr. [7 skyrių](#7-kitos-grandinės-net-php-python-mssql).

---

## 1. Kas kur veikia ir kodėl

```
                      GitHub (kodas + Actions)
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

| Platforma | Kam naudojame | Kaina |
|---|---|---|
| **Supabase** | PostgreSQL duomenų bazės (Test ir Prod – du projektai) | nemokamai: 2 aktyvūs projektai |
| **Render** | Docker konteineriai: API ir frontendai | nemokamai: 750 val./mėn. visai paskyrai |
| **GitHub Container Registry** | Docker image'ai | nemokamai viešiems paketams |
| **GitHub Actions** | build + deploy | nemokamai viešoms repozitorijoms |
| **Azure** (kitą savaitę) | Azure SQL (MSSQL) + Container Apps | Azure for Students: be kortelės |

**Kodėl ne viskas Supabase?** Supabase yra PostgreSQL kaip paslauga (+ Auth, Storage, Edge Functions Deno/TypeScript
aplinkoje). Joje **negalima paleisti savo Docker konteinerio**, todėl .NET / PHP / Python / Node.js API ir frontendai
veikia kitur (Render, Azure), o Supabase lieka duomenų bazei. MSSQL Supabase taip pat neturi – tam skirtas Azure SQL.

**Svarbiausias principas – „build once, deploy many“:** tas pats image'as keliauja į Test ir į Production.
Aplinkos skiriasi **tik nustatymais** (aplinkos kintamaisiais Render'yje): kuri duomenų bazė, kuris API adresas.
Kodas apie aplinką nieko nežino.

---

## 2. Vieną kartą: workflow'ai GitHub repozitorijoje

Workflow'ai turi būti **repozitorijos šaknyje**, aplanke `.github/workflows/`. Šiame laboratoriniame darbe jie laikomi
aplanke `deploy/github-workflows/`, kad juos būtų galima nukopijuoti į bet kurią repozitoriją.

```bash
cd SimpleStudentSystem
mkdir -p .github/workflows
cp deploy/github-workflows/*.yml .github/workflows/
```

Jei laboratorinis darbas repozitorijoje yra **kitame aplanke**, pakeisk `lab_dir:` reikšmę faile `deploy-test.yml` ir
`deploy-production.yml` (abiejuose).

| Failas | Ką daro |
|---|---|
| `_build-and-deploy.yml` | bendra dalis: Supabase migracijos → 6 projektų image'ai → ghcr.io → Render deploy hook |
| `check-migrations.yml` | PR'uose patikrina migracijas laikinoje PostgreSQL |
| `deploy-test.yml` | paleidžiamas push į `release/**`; versija iš šakos pavadinimo |
| `deploy-production.yml` | paleidžiamas žymei `v*.*.*`; patikrina, kad žymė yra `main` šakoje |

Projektas išdiegiamas tik tada, kai GitHub aplinkoje yra jo **secret**'as (pvz. `RENDER_HOOK_NODEAPI`).
Be secret'o image'as vis tiek sukuriamas ir įkeliamas į ghcr.io – paruoštas vėlesniam diegimui.

### GitHub Environments

Repozitorija → **Settings → Environments → New environment**:

1. `test`
2. `production`, papildomai:
   - **Required reviewers** – pridėk save: Production diegimas lauks tavo patvirtinimo (gera demonstracija studentams;
     prieinama viešoms repozitorijoms).
   - **Deployment branches and tags → Selected branches and tags → Add rule → Tag: `v*`** – į Production galima
     diegti tik iš release žymės.

Secret'us (deploy hook'us) pridėsime 5 žingsnyje, kai turėsime Render servisus.

### Workflow'ų leidimai

Repozitorija → **Settings → Actions → General → Workflow permissions → Read and write permissions** (reikia, kad
`GITHUB_TOKEN` galėtų įkelti image'us į ghcr.io). Organizacijoje tą patį gali tekti įjungti ir organizacijos nustatymuose.

---

## 3. Vieną kartą: Supabase duomenų bazės (Test ir Production)

> **SimpleStudentSystem repozitorijoje lentelė kuriama automatiškai** – migracijos `supabase/migrations` pritaikomos per GitHub Actions (job'as „database“). Žemiau aprašytas rankinis būdas lieka kaip atsarginis / vietiniam mokymuisi. Žr. **[SUPABASE_LT.md](SUPABASE_LT.md)**. Projektai: Test – `SimpleStudent System Test` (`xkkzlqedgvztdlvgerbu`), Production – `SimpleStudentSystem` (`ptkcvmldafnczhrixvcf`).

1. https://supabase.com → **Start your project** → prisijunk su GitHub.
2. **New project** du kartus:

   | | Test | Production |
   |---|---|---|
   | Name | `simplestudent-test` | `simplestudent-prod` |
   | Database Password | sugeneruok ir **išsisaugok** | kitas, taip pat išsisaugok |
   | Region | Central EU (Frankfurt) | Central EU (Frankfurt) |

3. Kiekviename projekte: **SQL Editor → New query** → įklijuok visą `database/postgres/create.sql` → **Run**.
   Sukuriama lentelė `Students` su 3 demonstraciniais studentais. **Table Editor** turi ją rodyti.
   Kad matytųsi skirtumas, Production projekte gali pakeisti vieno studento vardą.
4. Kiekviename projekte: viršuje **Connect** → **Connection String** → **Method: Session pooler** → nukopijuok URI:

   ```
   postgresql://postgres.abcdefghijklmnop:[YOUR-PASSWORD]@aws-0-eu-central-1.pooler.supabase.com:5432/postgres
   ```

   Vietoj `[YOUR-PASSWORD]` įrašyk projekto slaptažodį. Jei slaptažodyje yra simbolių `@ : / ? # %`, juos reikia
   užkoduoti (pvz. `@` → `%40`) – paprasčiau sugeneruoti slaptažodį tik iš raidžių ir skaičių.

**Kodėl Session pooler, o ne Direct connection?** Nemokamame plane tiesioginis prisijungimas veikia tik per IPv6, o
Render jungiasi per IPv4. Session pooler (portas 5432) veikia per IPv4 ir tinka ilgai veikiantiems serveriams.

**Kodėl `create.sql` gale yra `ENABLE ROW LEVEL SECURITY`?** Supabase kiekvieną `public` schemos lentelę automatiškai
publikuoja per savo REST API su viešu „anon“ raktu. RLS be jokių taisyklių tą kelią uždaro, o mūsų API jungiasi kaip
lentelės savininkas (`postgres`) ir RLS jo neriboja.

> Nemokamas Supabase projektas po **7 dienų be veiklos sustabdomas** (paused). Prieš paskaitą atidaryk projektą ir
> paspausk **Restore project** – užtrunka kelias minutes.

---

## 4. Pirmasis image'ų sukūrimas

Render servisą iš image'o galima sukurti tik tada, kai image'as jau egzistuoja. Todėl pirmąkart tiesiog paleidžiame
release – be secret'ų workflow'as sukurs ir įkels image'us, bet nieko nediegs.

```bash
git checkout develop
git pull
git checkout -b release/v1.3.0
git push -u origin release/v1.3.0
```


GitHub → **Actions → deploy-test**: turi būti 6 žali job'ai. Image'ai matomi repozitorijos puslapyje dešinėje,
skiltyje **Packages**: `simplestudentsystem-nodeapi`, `simplestudentsystem-phpfrontend`, `simplestudentsystem-dotnetapi` ir t. t.

### Padaryk paketus viešus

Pagal nutylėjimą organizacijos paketai būna **privatūs** – Render jų nepasieks. Kiekvienam paketui, kurį diegsime:

**Packages → paketas → Package settings → Danger Zone → Change visibility → Public.**

Rytojui pakanka dviejų: `simplestudentsystem-nodeapi` ir `simplestudentsystem-phpfrontend`.
(Alternatyva privatiems paketams: Render → Workspace Settings → Container Registry Credentials, GitHub token su
`read:packages` teise.)

---

## 5. Vieną kartą: Render servisai

https://render.com → prisijunk su GitHub. Kiekvienam servisui: **New → Web Service → Existing Image**.

### 5.1 Node.js API (Test ir Production)

| Laukas | Test | Production |
|---|---|---|
| Image URL | `ghcr.io/tadasbulis-practice/simplestudentsystem-nodeapi:test` | `ghcr.io/tadasbulis-practice/simplestudentsystem-nodeapi:latest` |
| Name | `simplestudent-nodeapi-test` | `simplestudent-nodeapi-prod` |
| Region | Frankfurt (EU Central) | Frankfurt (EU Central) |
| Instance Type | **Free** | **Free** |

Production image'as `:latest` atsiras tik po pirmojo Production release (8 skyrius). Iki tol Production servisą gali
sukurti su `:test` – kitas deploy hook'as jį vis tiek perjungs į tikslią versiją.

**Environment Variables** (Add from .env – galima įklijuoti visus iš karto):

```
DB_DRIVER=postgres
DB_SSL=true
DATABASE_URL=postgresql://postgres.xxxx:SLAPTAZODIS@aws-0-eu-central-1.pooler.supabase.com:5432/postgres
APP_ENVIRONMENT=Test
APP_DEBUG=true
PORT=8080
```

Production servisui: `DATABASE_URL` iš **simplestudent-prod**, `APP_ENVIRONMENT=Production`, `APP_DEBUG=false`.

Po sukūrimo atidaryk `https://simplestudent-nodeapi-test.onrender.com/swagger` ir `/api/info` – matysi `"environment": "Test"`
ir versiją `1.3.0-rc.N`.

### 5.2 PHP frontendas (Test ir Production)

| Laukas | Test | Production |
|---|---|---|
| Image URL | `ghcr.io/tadasbulis-practice/simplestudentsystem-phpfrontend:test` | `ghcr.io/tadasbulis-practice/simplestudentsystem-phpfrontend:latest` |
| Name | `simplestudent-phpfrontend-test` | `simplestudent-phpfrontend-prod` |
| Instance Type | **Free** | **Free** |

```
API_BASE_URL=https://simplestudent-nodeapi-test.onrender.com
API_PUBLIC_URL=https://simplestudent-nodeapi-test.onrender.com
DOTNET_FRONTEND_URL=https://simplestudent-dotnetfrontend-test.onrender.com
PORT=80
```

Production: tie patys kintamieji su `-prod` adresais. **Čia ir yra frontendo „baseURL“ nukreipimas į atitinkamos aplinkos
API** – kodas tas pats, skiriasi tik šie nustatymai.

Tikslų serviso adresą matysi Render serviso puslapio viršuje (jei vardas užimtas, Render prideda priesagą).

### 5.3 Deploy hook'ai → GitHub secret'ai

Kiekvieno Render serviso **Settings → Deploy Hook** → nukopijuok URL (`https://api.render.com/deploy/srv-...?key=...`).

GitHub → **Settings → Environments → test → Add environment secret**:

| Secret | Reikšmė |
|---|---|
| `RENDER_HOOK_NODEAPI` | `simplestudent-nodeapi-test` deploy hook |
| `RENDER_HOOK_PHPFRONTEND` | `simplestudent-phpfrontend-test` deploy hook |

Tas pats **production** aplinkoje su `-prod` servisų hook'ais.

Deploy hook'as yra slaptas: kas jį žino, gali perdiegti servisą. Duomenų bazės slaptažodžiai GitHub'e **nesaugomi** –
jie yra tik Render nustatymuose.

---

## 6. Kaip veikia workflow'as (ką rodyti studentams)

1. `deploy-test.yml` iš šakos `release/v1.3.0` ištraukia versiją `1.3.0` ir prideda `-rc.<paleidimo nr.>`.
2. `_build-and-deploy.yml` kiekvienam projektui (matrix):
   - `docker build` su `APP_VERSION=1.3.0-rc.4` (Node API ją rodo `/api/info`),
   - `docker push` į `ghcr.io/<owner>/<repo>-<projektas>` su dviem žymėmis: `1.3.0-rc.4` ir `test`,
   - jei yra secret'as – `curl` į Render deploy hook su `imgURL=...:1.3.0-rc.4`.
3. Render parsisiunčia būtent tą image'ą ir paleidžia jį su **savo** aplinkos kintamaisiais.
4. `deploy-production.yml` daro tą patį su žyme `v1.3.0` → image `1.3.0` ir `latest`, bet tik jei žymė yra `main`
   šakoje ir (jei įjungta) tik po tavo patvirtinimo.

Actions puslapyje kiekvieno paleidimo **Summary** rodo lentelę: kuris projektas sukurtas, kuris išdiegtas.

---

## 7. Kitos grandinės (.NET, PHP, Python, MSSQL)

Visi projektai jau kuriami workflow'e. Kad projektas būtų išdiegtas, reikia Render serviso (5 skyrius) ir secret'o.

| Projektas | Secret | Render PORT | Aplinkos kintamieji (Test / Prod skiriasi reikšmėmis) |
|---|---|---|---|
| Node.js API | `RENDER_HOOK_NODEAPI` | 8080 | `DB_DRIVER=postgres`, `DB_SSL=true`, `DATABASE_URL` – arba `DB_DRIVER=sqlsrv` + `DB_HOST` … Azure SQL |
| .NET API | `RENDER_HOOK_DOTNETAPI` | 8080 | `ConnectionStrings__DefaultConnection` (Azure SQL), `ASPNETCORE_ENVIRONMENT` |
| PHP API | `RENDER_HOOK_PHPAPI` | 80 | `DB_DRIVER=sqlsrv`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `APP_ENVIRONMENT` |
| Python API | `RENDER_HOOK_PYTHONAPI` | 8080 | tie patys `DB_*` kaip PHP API |
| .NET frontendas (Razor Pages) | `RENDER_HOOK_DOTNETFRONTEND` | 8080 | `ApiSettings__BaseUrl`, `ApiSettings__PublicUrl`, `ApiSettings__PhpFrontendUrl` |
| PHP frontendas | `RENDER_HOOK_PHPFRONTEND` | 80 | `API_BASE_URL`, `API_PUBLIC_URL`, `DOTNET_FRONTEND_URL` |

Abu frontendai API adresą skaito **paleidimo metu** (runtime) iš aplinkos kintamųjų, todėl tas pats image'as tinka
abiem aplinkoms. (Blazor WebAssembly to nedaro – jo nustatymai yra statiniame `wwwroot/appsettings.json`, todėl jį
diegiant reikėtų papildomo žingsnio; šiame gide jo nėra.)

**Kurią DB gali naudoti kuris API šiandien:**

| API | Supabase (PostgreSQL) | Azure SQL (MSSQL) |
|---|---|---|
| Node.js | ✔ | ✔ (`DB_SSL=true`) |
| .NET | – (reikėtų Npgsql paketo) | ✔ |
| PHP | – (reikėtų `pdo_pgsql` plėtinio) | ✔ |
| Python | – (reikėtų `psycopg` paketo) | ✔ |

MSSQL debesyje = **Azure SQL Database** (nemokamas pasiūlymas: iki 10 DB, 100 000 vCore sekundžių per mėnesį kiekvienai).
Test ir Production – dvi atskiros duomenų bazės. Azure SQL grandinė – kitos savaitės tema; workflow'ai nesikeis,
pasikeis tik Render (arba Azure Container Apps) nustatymai.

---

## 8. Demonstracija: release nuo pradžios iki galo

### 8.1 Release → Test

```bash
git checkout develop
git pull
git checkout -b release/v1.3.0
git push -u origin release/v1.3.0
```

Arba su git-flow įrankiu (`git flow init` metu „Version tag prefix“ nustatyk `v`):

```bash
git flow release start 1.3.0
git flow release publish 1.3.0
```

Patikrink:

- GitHub → **Actions → deploy-test** – žalias,
- `https://simplestudent-nodeapi-test.onrender.com/api/info` → `"environment": "Test"`, `"version": "1.3.0-rc.N"`,
- `https://simplestudent-phpfrontend-test.onrender.com` → studentai iš **Test** duomenų bazės.

Pataisymas release šakoje (pvz. pakeistas tekstas) → commit → push → automatiškai naujas `rc` Test aplinkoje.

### 8.2 Release užbaigimas → Production

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

Arba su git-flow:

```bash
git flow release finish 1.3.0
git push origin main develop --tags
```

Patikrink:

- GitHub → **Actions → deploy-production** → (jei įjungei reviewers) **Review deployments → Approve**,
- `https://simplestudent-nodeapi-prod.onrender.com/api/info` → `"environment": "Production"`, `"version": "1.3.0"`,
- `https://simplestudent-phpfrontend-prod.onrender.com` → studentai iš **Production** duomenų bazės.

Jei pull request'ai yra privalomi `main` šakai, merge daromas per PR (`release/v1.3.0` → `main`), o po jo žymė
sukuriama ant `main` ir išsiunčiama `git push origin v1.3.0`.

---

## 9. Dažniausios problemos

| Simptomas | Priežastis / sprendimas |
|---|---|
| Pirmas puslapis kraunasi ~1 min. arba PHP frontendas rodo „Cannot reach the API“ | Nemokamas Render servisas po 15 min. užmiega. Prieš paskaitą atidaryk abiejų aplinkų `/api/info` ir palauk, kol atsakys, tada perkrauk frontendą. |
| Render: `pull access denied` / `unauthorized` | Paketas ghcr.io privatus – 4 skyrius, „Change visibility → Public“. |
| deploy hook: `400 Bad Request` | Render serviso Image URL kitas nei workflow'o image'as (pvz. kita repozitorija / savininkas). Turi sutapti viskas, išskyrus žymę po `:`. |
| `/api/info` veikia, `/api/students` → 500 „Database error“ | Patikrink `DATABASE_URL` (Session pooler, slaptažodis, `DB_SSL=true`). Supabase projektas gal sustabdytas (paused). |
| `ENETUNREACH` / `getaddrinfo` su `db.xxxx.supabase.co` | Naudojamas Direct connection (IPv6). Naudok Session pooler URI. |
| `deploy-production`: „not on main“ | Žymė sukurta ant release šakos commit'o prieš merge'ą. Ištrink žymę ir sukurk ją ant `main`. |
| `deploy-test`: „not release/vX.Y.Z“ | Šakos pavadinimas turi būti `release/v1.3.0` arba `release/1.3.0`. |
| Actions: `denied: installation not allowed to Write organization package` | Settings → Actions → General → Workflow permissions → Read and write (2 skyrius). |
| Render „No open ports detected“ | Nepridėtas `PORT` kintamasis (Node/.NET/Python: 8080, PHP: 80). |

---

## 10. Kitą savaitę: Azure

- **Azure SQL Database** (free offer) – Test ir Production MSSQL duomenų bazės; `database/…/create.sql` per Query editor.
- **Azure Container Apps** – tie patys ghcr.io image'ai; workflow'e deploy hook'o žingsnį papildys
  `az containerapp update --image ...` (prisijungimas su `azure/login`, OIDC).
- PostgreSQL palaikymas PHP / Python / .NET API, kad visi API galėtų naudoti Supabase.
