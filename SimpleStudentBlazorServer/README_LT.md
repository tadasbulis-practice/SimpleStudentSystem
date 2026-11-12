# SimpleStudentBlazorServer

Students frontend'as, sukurtas su **Blazor** (.NET 8 Blazor Web App), render mode **Interactive Server**.
Jis kviečia tą patį API kaip Razor Pages frontend'as (`SimpleStudentFrontend`) ir PHP frontend'as, su tuo pačiu
iš `swagger.json` sugeneruotu tipizuotu klientu, ir veikia su **.NET, PHP ir Python API**.
English: [README.md](README.md).

## Kaip tai veikia

```
Naršyklė ──SignalR (WebSocket)──► Blazor Server konteineris ──HTTP + JSON──► API (.NET / PHP / Python)
         ◄── tik pasikeitusios     (komponentai vykdomi čia,
             puslapio dalys)        IStudentApiClient kviečia API)
```

- **Komponentai vykdomi serveryje.** Naršyklė laiko atvirą SignalR jungtį, siunčia paspaudimus ir klavišus,
  o gauna tik pasikeitusias puslapio dalis. Viso puslapio perkrovimų nėra.
- **API kviečia serveris**, kaip ir Razor Pages atveju, todėl API nereikia CORS, o API adresai gali būti
  vidiniai Docker vardai (`http://simplestudentapi:8080`).
- Kiekviena naršyklės kortelė turi savo būseną serveryje (*circuit*). Nutrūkus jungčiai, puslapis rodo
  „Attempting to reconnect…“.

## Ką pavyzdys rodo (lyginant su Razor Pages frontend'u)

| Savybė | Kur |
|---|---|
| **API perjungiklis** (.NET / PHP / Python): duomenys perkraunami, puslapis ne | `Components/Layout/ApiSwitcher.razor`, `Services/ApiConnection.cs` |
| **Gyva paieška**: lentelė filtruojama po kiekvieno klavišo paspaudimo | `Components/Pages/Students.razor` (`@bind:event="oninput"`) |
| **Trynimo patvirtinimas eilutėje**: be naršyklės dialogo ir be perkrovimo | `Components/Pages/Students.razor` |
| **Validacija rašant**: taisyklės ateina iš swagger.json (`[Required]`, `[StringLength]`, `[Range]` sugeneruotoje `Student` klasėje) | `Components/Shared/StudentForm.razor` (`DataAnnotationsValidator`) |
| **API klaidos prie laukų**: 400 ValidationProblem susiejamas su įvesties laukais | `Components/Shared/StudentForm.razor` (`ValidationMessageStore`) |
| **Viena forma kūrimui ir redagavimui**: pakartotinai naudojamas komponentas | `StudentForm.razor`, naudojamas `StudentEdit.razor` (`/students/new`, `/students/{id}/edit`) |
| **Fakulteto grupės**: išskleidimas C# kalba, be JavaScript | `Components/Pages/Faculty.razor` |
| **Kur vykdomas kodas?** | `Components/Shared/RuntimeBadge.razor` |

```
SimpleStudentBlazorServer/
├── Program.cs                     ← AddRazorComponents().AddInteractiveServerComponents()
├── appsettings.json               ← "Backends": .NET, PHP, Python (BaseUrl = serveris → API)
├── ApiClient/                     ← NSwag sugeneruotas StudentApiClient.g.cs + generate-client.sh/.ps1
├── Services/ApiConnection.cs      ← pasirinktas backend'as + jo tipizuotas klientas (vienas kortelei)
├── Components/
│   ├── App.razor                  ← HTML apvalkalas, render mode InteractiveServer visiems puslapiams
│   ├── Routes.razor               ← maršrutizatorius
│   ├── Layout/                    ← MainLayout (navigacija), ApiSwitcher
│   ├── Pages/                     ← Home, Students, StudentDetails, StudentEdit, Faculty
│   └── Shared/                    ← StudentForm, RuntimeBadge
├── wwwroot/app.css                ← ta pati išvaizda kaip Razor Pages frontend'o
└── Dockerfile
```

## Paleidimas per Docker

Iš aplanko `student-docker-lab-plus-mssql`:

```bash
docker-compose -f docker-compose.infra.yml up -d
docker-compose up --build
```

Atidarykite **http://localhost:6031**. `docker-compose.yml` faile backend'ų adresai yra Docker servisų vardai
(`Backends__0__BaseUrl: http://simplestudentapi:8080`, …), nes Blazor serveris kviečia API Docker tinklo viduje. Ketvirtas pasirinkimas, **PHP (XAMPP)**, yra PHP API
XAMPP'e jūsų kompiuteryje: konteineris jį pasiekia adresu `http://host.docker.internal:8080/simpleStudentApi/`.

## Paleidimas lokaliai (dotnet run)

API turi veikti (Docker, XAMPP arba `python main.py`). Numatytieji adresai `appsettings.json` faile:
`localhost:6001` (.NET), `localhost:6002` (PHP), `localhost:6003` (Python) ir
`localhost:8080/simpleStudentApi/` (PHP XAMPP'e, Apache prievadas 8080).

```bash
dotnet run
```

Atidarykite **http://localhost:6031**. Jei jūsų XAMPP Apache naudoja kitą prievadą ar katalogą, pakeiskite
`PHP (XAMPP)` įrašą faile `appsettings.json` (pvz. `http://localhost/simpleStudentApi/` prievadui 80).
Adresas su katalogu veikia ir be galinio `/` – jį prideda `ApiConnection.ToBaseUri`.

## API kliento pergeneravimas

Pasikeitus API kontraktui (API turi veikti prievadu 6001):

```bash
cd ApiClient
bash generate-client.sh
```

Windows: `.\generate-client.ps1`. Reikia Node.js (`npx` atsisiunčia NSwag).

## Problemų sprendimas

| Problema | Sprendimas |
|---|---|
| „Cannot reach the API: Connection refused“ | pasirinktas API neveikia: paleiskite jį arba pasirinkite kitą viršuje dešinėje |
| „Attempting to reconnect to the server…“ | Blazor konteineris perkrautas arba nutrūko tinklas; puslapis prisijungs pats |
| Po F5 API pasirinkimas dingsta | taip ir turi būti: pasirinkimas saugomas kortelės būsenoje serveryje, perkrovus kuriama nauja |
| Prievadas 6031 užimtas | pakeiskite `applicationUrl` faile `Properties/launchSettings.json` |
