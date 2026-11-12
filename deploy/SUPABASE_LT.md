# Supabase duomenų bazė: automatinis diegimas į Test ir Production

English: [SUPABASE.md](SUPABASE.md) · Bendras diegimo gidas (Render, ghcr.io): [DEPLOYMENT_LT.md](DEPLOYMENT_LT.md)

Duomenų bazės struktūra laikoma **git'e kaip migracijos** (`supabase/migrations/*.sql`). GitHub Actions jas pats
pritaiko atitinkamam Supabase projektui – ranka SQL Editor'iuje nieko vykdyti nebereikia.

| Git veiksmas | GitHub environment | Supabase projektas | Workflow |
|---|---|---|---|
| Pull request / push į `develop` (keičiant `supabase/`) | – | laikina PostgreSQL GitHub runner'yje | `check-migrations.yml` |
| push į `release/vX.Y.Z` | `test` | **SimpleStudent System Test** (`xkkzlqedgvztdlvgerbu`) | `deploy-test.yml` |
| `release/vX.Y.Z` → `main` + žymė `vX.Y.Z` | `production` | **SimpleStudentSystem** (`ptkcvmldafnczhrixvcf`) | `deploy-production.yml` |

Abiejose aplinkose eiliškumas tas pats: **1) duomenų bazė** (migracijos + demo duomenys) → **2) API Supabase'e**
(Edge Function, [6 skyrius](#6-api-pačiame-supabase-edge-function-simplestudent-api)) ir **Docker image'ai** → Render. Taip naujas kodas niekada nepaleidžiamas su sena lentele.

---

## 1. Kas yra repozitorijoje

```
supabase/
├── config.toml                                   <- `supabase init` failas (vietiniam Supabase, CLI nustatymai)
├── migrations/
│   └── 20261112000000_create_students.sql        <- lentelė "Students" + Row Level Security
└── seed.sql                                      <- 3 demo studentai (tik jei lentelė tuščia)
database/postgres/create.sql                      <- ta pati lentelė vietiniam Docker PostgreSQL
.github/workflows/
├── _build-and-deploy.yml                         <- job "database" (supabase db push) → job "image" (Docker + Render)
├── deploy-test.yml                               <- release/** → environment "test"
├── deploy-production.yml                         <- tag v*.*.* ant main → environment "production"
└── check-migrations.yml                          <- migracijų patikra PR'uose (be jokių slaptažodžių)
```

**Migracija** – SQL failas su laiko žyme pavadinime. Supabase lentelėje `supabase_migrations.schema_migrations`
įsimena, kurie failai jau pritaikyti, todėl kiekvienas failas vykdomas **tik vieną kartą** kiekvienoje DB.
Jau pritaikyto failo **nekeičiame** – kiekvienas pakeitimas yra naujas failas.

**Seed** (`seed.sql`) – demonstraciniai duomenys. `supabase db push --include-seed` jį vykdo vieną kartą
(ir dar kartą tik pasikeitus failui). `WHERE NOT EXISTS` apsaugo: jei lentelėje jau yra duomenų, nieko neįrašoma.

---

## 2. Vieną kartą: GitHub nustatymai (dėstytojas)

### 2.1 Environments

Repozitorija → **Settings → Environments → New environment**:

1. `test`
2. `production`, papildomai:
   - **Required reviewers** → pridėk save (Production diegimas lauks patvirtinimo),
   - **Deployment branches and tags → Selected branches and tags → Tag: `v*`**.

### 2.2 Secret'ai ir kintamieji

Kiekvienoje aplinkoje: **Environment secrets → Add secret** ir **Environment variables → Add variable**.

| Aplinka | Tipas | Pavadinimas | Reikšmė |
|---|---|---|---|
| `test` | secret | `SUPABASE_DB_URL` | `postgresql://postgres.xkkzlqedgvztdlvgerbu:SLAPTAZODIS@aws-0-eu-central-1.pooler.supabase.com:5432/postgres` |
| `test` | variable | `SUPABASE_PROJECT_REF` | `xkkzlqedgvztdlvgerbu` |
| `production` | secret | `SUPABASE_DB_URL` | `postgresql://postgres.ptkcvmldafnczhrixvcf:SLAPTAZODIS@aws-1-eu-west-1.pooler.supabase.com:5432/postgres` |
| `production` | variable | `SUPABASE_PROJECT_REF` | `ptkcvmldafnczhrixvcf` |

`SLAPTAZODIS` – projekto **Database password** (Supabase → Project Settings → Database). Jei jame yra
`@ : / ? # %`, juos reikia užkoduoti (`@` → `%40`).

**Slaptažodžiai niekada nerašomi į repozitoriją** – tik į GitHub secret'us (ir Render nustatymus). Secret'ų reikšmių
negali matyti niekas, net repozitorijos administratorius; logai juos automatiškai užmaskuoja (`***`).

Jei secret'o nėra, job'as „database“ praleidžiamas su pranešimu – image'ai vis tiek sukuriami.

### 2.3 Kodėl Session pooler, o ne Direct connection?

`db.<ref>.supabase.co` (Direct connection) nemokamame plane veikia **tik per IPv6**, o GitHub Actions runner'iai ir
Render turi tik IPv4. **Session pooler** (`aws-…pooler.supabase.com:5432`, vartotojas `postgres.<ref>`) veikia per
IPv4 ir palaiko viską, ko reikia migracijoms. Todėl ir CI, ir API naudoja Session pooler URI.

### 2.4 Pirmasis paleidimas su jau egzistuojančia lentele

Jei `create.sql` jau buvo paleistas ranka SQL Editor'iuje – nieko daryti nereikia: migracija naudoja
`CREATE TABLE IF NOT EXISTS`, o seed neįrašo duomenų į netuščią lentelę. Po pirmo `db push` Supabase tiesiog
pažymi migraciją kaip pritaikytą.

---

## 3. Kasdienis darbas: nauja migracija (studentas / komanda)

Reikia [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started)
(`brew install supabase/tap/supabase`, Windows: `scoop install supabase`, arba `npx supabase …`).

```bash
git checkout develop && git pull
git checkout -b feature/student-phone

supabase migration new add_phone_to_students
# → sukuriamas supabase/migrations/<data-laikas>_add_phone_to_students.sql
```

Faile:

```sql
ALTER TABLE "Students" ADD COLUMN IF NOT EXISTS "Phone" varchar(30);
```

Patikrink vietoje (bet kuris variantas):

```bash
# a) vietinis Docker PostgreSQL iš docker-compose.postgres.yml
supabase db push --remote="postgresql://postgres:1Secure*Password1@localhost:5432/StudentDb" --include-seed --yes

# b) pilnas vietinis Supabase (Docker; Studio http://localhost:54323)
supabase start
supabase db reset          # visos migracijos + seed.sql nuo nulio
```

Tada `git add supabase/ && git commit && git push` → pull request į `develop` → **check-migrations** turi būti žalias.
Nepamiršk atnaujinti ir API (modelis, Swagger kontraktas) bei `database/postgres/create.sql` vietiniam Docker'iui.

### Ką pamatysi release metu

- **Actions → deploy-test → Supabase database (test)** – log'e `Applying migration …_add_phone_to_students.sql…`,
  **Summary** – migracijų sąrašas ir nuoroda į Table Editor.
- Supabase **Table Editor** (Test projektas) – naujas stulpelis. Production projekte jo dar nėra – atsiras tik po
  `vX.Y.Z` žymės ant `main`.

### Peržiūra prieš diegiant (be pakeitimų)

```bash
supabase db push --remote="<Session pooler URI>" --include-seed --dry-run
```

---

## 4. Savo kopija (studentams)

Repozitorija vieša, tad studentai gali ją peržiūrėti, bet negali keisti ir nemato secret'ų. Norint pasidaryti savo
veikiančią versiją:

1. **Fork** (arba **Use this template**) → savo GitHub paskyroje.
2. Supabase → du nemokami projektai (Test, Production) → kiekviename nukopijuok Session pooler URI.
3. Savo repozitorijoje: 2 skyriaus `test` ir `production` aplinkos, secret'ai `SUPABASE_DB_URL`,
   kintamieji `SUPABASE_PROJECT_REF`. Settings → Actions → General → Workflow permissions → **Read and write**.
4. `git checkout -b release/v0.1.0 && git push -u origin release/v0.1.0` → tavo Test DB sukuriama automatiškai.

---

## 5. Dažniausios problemos

| Simptomas | Priežastis / sprendimas |
|---|---|
| `failed to connect … db.xxxx.supabase.co` / `network is unreachable` | Naudojamas Direct connection (IPv6). Secret'e turi būti **Session pooler** URI. |
| `password authentication failed for user "postgres"` | Pooler'iui vartotojas yra `postgres.<project-ref>`, ne `postgres`; arba neteisingas / neužkoduotas slaptažodis. |
| `Tenant or user not found` | Neteisingas regionas pooler'io adrese (Test: `aws-0-eu-central-1`, Prod: `aws-1-eu-west-1`) – nukopijuok URI iš **Connect** lango. |
| Job'as baigiasi per kelias sekundes, bet nieko nesikeičia | Projektas sustabdytas (paused po 7 d. neveiklos) → Supabase dashboard → **Restore project**. |
| `Remote migration versions not found in local migrations directory` | DB yra migracija, kurios nėra repozitorijoje (kažkas ištrynė / pervadino failą). Grąžink failą; kraštutiniu atveju `supabase migration repair --status reverted <versija>`. |
| Pakeičiau jau pritaikytą migraciją, bet DB nesikeičia | Taip ir turi būti – migracija vykdoma vieną kartą. Sukurk naują migraciją. |
| „No secret SUPABASE_DB_URL“ | Secret'as sukurtas repozitorijos lygyje arba kitoje aplinkoje – turi būti **Environment secret** aplinkoje `test` / `production`. |

---

## 6. API pačiame Supabase: Edge Function `simplestudent-api`

Supabase negali paleisti mūsų Docker konteinerių, bet turi **Edge Functions**: serverio kodą TypeScript/JavaScript
kalba, vykdomą **Deno** aplinkoje (Node.js npm paketai importuojami per `npm:`). Nemokamame plane:
500 000 iškvietimų per mėnesį. Python, PHP ir .NET čia neveikia, todėl Supabase'e paleidžiame **Node.js API**
versiją: tas pats Express kodas, tas pats `openapi.json` kontraktas, tas pats validatorius.

| | Node.js API (Docker → Render) | Edge Function API (Supabase) |
|---|---|---|
| Kodas | `SimpleStudentNodeApi/src/app.js` | `supabase/functions/simplestudent-api/index.ts` |
| Vykdymas | Node.js konteineris, veikia nuolat | Deno, paleidžiama kiekvienai užklausai (serverless) |
| DB prisijungimas | `DATABASE_URL` (Session pooler) | `SUPABASE_DB_URL` – Supabase pateikia pats |
| Diegimas | Docker image → ghcr.io → Render deploy hook | `supabase functions deploy` |
| Swagger UI | `/swagger` (HTML) | **GitHub Pages** – Edge Functions negali grąžinti HTML |

**Adresai** (po release):

| | Test | Production |
|---|---|---|
| API | `https://xkkzlqedgvztdlvgerbu.supabase.co/functions/v1/simplestudent-api/api/students` | `https://ptkcvmldafnczhrixvcf.supabase.co/functions/v1/simplestudent-api/api/students` |
| Info | `…/simplestudent-api/api/info` | `…/simplestudent-api/api/info` |
| Kontraktas | `…/simplestudent-api/swagger/v1/swagger.json` | `…/simplestudent-api/swagger/v1/swagger.json` |
| Swagger UI | `https://tadasbulis-practice.github.io/SimpleStudentSystem/?env=test` | `https://tadasbulis-practice.github.io/SimpleStudentSystem/?env=production` |

### 6.1 Vieną kartą: nustatymai

1. **Supabase prieigos raktas** (Edge Function diegimui; DB slaptažodžio tam neužtenka):
   supabase.com → avataras viršuje dešinėje → **Account preferences → Access Tokens → Generate new token**
   (pavadinimas pvz. `github-actions-SimpleStudentSystem`). Raktas tinka abiem projektams.
2. **GitHub secret** – vienas visai repozitorijai:
   ```bash
   gh secret set SUPABASE_ACCESS_TOKEN --repo tadasbulis-practice/SimpleStudentSystem
   ```
   (komanda paprašys įklijuoti reikšmę – ji nepateks į istoriją).
3. **Production tik skaitymui** (rekomenduojama – API viešas, be prisijungimo):
   ```bash
   gh variable set API_READ_ONLY --env production --repo tadasbulis-practice/SimpleStudentSystem --body true
   ```
   Test aplinkoje POST / PUT / DELETE veikia – studentai gali eksperimentuoti. Production'e jie grąžina `403`.
4. **GitHub Pages:** Settings → **Pages → Build and deployment → Source: GitHub Actions**.
   Puslapis (`swagger-ui/index.html`) publikuojamas kiekvieną kartą pasikeitus `main` (t. y. kiekvieno Production
   release metu) arba Actions → **pages → Run workflow**.

### 6.2 Ką daro workflow'as

`_build-and-deploy.yml` job'as **Supabase Edge Function API** (po migracijų):

1. `supabase secrets set` – funkcijos nustatymai: `APP_ENVIRONMENT` (Test / Production), `APP_VERSION`
   (pvz. `1.1.0-rc.3`), `API_READ_ONLY`, `SWAGGER_UI_URL`;
2. `supabase functions deploy simplestudent-api --use-api --no-verify-jwt` – Supabase pats sukompiliuoja ir išdiegia;
3. **smoke test**: `GET /api/info` turi grąžinti būtent šią versiją, `GET /api/students` – studentų sąrašą.

Be `SUPABASE_ACCESS_TOKEN` job'as praleidžiamas su pranešimu. `check-migrations.yml` PR'uose papildomai patikrina,
kad funkcija kompiliuojasi (`deno check`, `deno lint`) ir kad jos `openapi.json`, `validator.js`, `problems.js`
kopijos **sutampa** su `SimpleStudentNodeApi` – vienas kontraktas visiems API.

`verify_jwt = false` (`supabase/config.toml`) – API kviečiamas be Supabase rakto, kaip ir Render API.

### 6.3 Vietoje (Supabase CLI + Docker)

```bash
supabase start
supabase functions serve
```

Tada `http://localhost:54321/functions/v1/simplestudent-api/api/students`. Funkcija naudoja vietinę Supabase DB
(`supabase db reset` sukuria lentelę ir demo duomenis).

Pakeitei kontraktą `SimpleStudentNodeApi/openapi/openapi.json`? Nukopijuok jį ir į funkciją:

```bash
cp SimpleStudentNodeApi/openapi/openapi.json SimpleStudentNodeApi/src/validator.js SimpleStudentNodeApi/src/problems.js supabase/functions/simplestudent-api/
```

### 6.4 Problemos

| Simptomas | Priežastis / sprendimas |
|---|---|
| `Unauthorized` / `401` diegiant | `SUPABASE_ACCESS_TOKEN` neteisingas arba atšauktas – sugeneruok naują. |
| Smoke test: versija nesutampa | Funkcija dar paleista su senais secret'ais – paleisk job'ą dar kartą (Re-run). |
| Naršyklėje `/swagger` rodo JSON | Taip ir turi būti: Edge Functions negali grąžinti HTML. Atidaryk Swagger UI GitHub Pages adresu. |
| Swagger UI: „API not reachable“ | Funkcija dar neišdiegta tame projekte arba projektas sustabdytas (paused). |
| `403 This environment is read-only` | `API_READ_ONLY=true` šioje aplinkoje – naudok Test. |
| `500 Database error` | Lentelės nėra (migracijos nepritaikytos) – žr. job'ą „Supabase database“. |
