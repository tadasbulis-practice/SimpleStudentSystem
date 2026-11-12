# SimpleStudentBlazorWasm

Students frontend'as, sukurtas su **Blazor WebAssembly** (.NET 8, standalone). Visa programa, įskaitant
C# kodą, **atsisiunčiama į naršyklę ir vykdoma joje**. Ji naudoja tuos pačius komponentus ir tą patį tipizuotą
klientą (sugeneruotą iš `swagger.json`) kaip `SimpleStudentBlazorServer` ir veikia su **.NET, PHP ir Python API**.
English: [README.md](README.md).

## Kaip tai veikia

```
                 1. atsisiunčia index.html, programos .dll failus ir .NET runtime (.wasm)
Naršyklė ◄─────────────────────────────────────────── nginx konteineris (tik statiniai failai, be .NET)

Naršyklė ──HTTP + JSON (fetch)──► API (.NET :6001 / PHP :6002 / Python :6003 / PHP XAMPP'e :8080/simpleStudentApi)
   ▲  2. C# kodas vykdomas ČIA ir kviečia API tiesiogiai – API turi tai leisti per CORS
```

- Po pirmo atsisiuntimo serverio nebereikia: paspaudimai, validacija ir puslapių keitimas vyksta naršyklėje.
  Kviečiamas tik API.
- API užklausas siunčia **naršyklė**, todėl API adresai turi būti pasiekiami **iš naršyklės**
  (`http://localhost:6001`, ne Docker vardas `simplestudentapi:8080`), o API turi siųsti **CORS** antraštes
  (`Access-Control-Allow-Origin`). Visi trys API tai daro:
  .NET – `AddCors()` / `UseCors()` faile `SimpleStudentApi/Program.cs`, PHP – `Http::cors()`,
  Python – `CORSMiddleware` faile `main.py`.
- Atidarykite naršyklės kūrėjo įrankius (F12 → **Network**): matysite kiekvieną užklausą į API.
  Su Blazor Server ar Razor Pages nematytumėte nė vienos, nes API kviečia serveris.

## Palyginimas su SimpleStudentBlazorServer

Puslapiai (`Pages/`, `Layout/`, `Shared/`) yra **tie patys komponentai**. Skiriasi:

| | Blazor Server | Blazor WebAssembly |
|---|---|---|
| Projekto SDK | `Microsoft.NET.Sdk.Web` | `Microsoft.NET.Sdk.BlazorWebAssembly` + 2 NuGet paketai |
| `Program.cs` | `WebApplication` + `AddInteractiveServerComponents()` | `WebAssemblyHostBuilder` (vykdomas naršyklėje) |
| HTML apvalkalas | `Components/App.razor` | `wwwroot/index.html` |
| Nustatymai | `appsettings.json` (gali būti slaptos reikšmės) | `wwwroot/appsettings.json` – **viešas**, bet kuris lankytojas gali jį atsisiųsti |
| HttpClient | iš `IHttpClientFactory` serveryje | `new HttpClient()` = naršyklės `fetch()` |
| Talpinimas | ASP.NET Core serveris (.NET runtime) | bet koks statinių failų web serveris (čia nginx) |

```
SimpleStudentBlazorWasm/
├── Program.cs                  ← WebAssemblyHostBuilder, skaito "Backends" iš wwwroot/appsettings.json
├── App.razor                   ← maršrutizatorius
├── Layout/  Pages/  Shared/    ← tie patys komponentai kaip SimpleStudentBlazorServer
├── Services/ApiConnection.cs   ← pasirinktas backend'as + tipizuotas klientas (HttpClient → naršyklės fetch)
├── ApiClient/                  ← NSwag sugeneruotas StudentApiClient.g.cs + generate-client.sh/.ps1
├── wwwroot/
│   ├── index.html              ← puslapis, kuris įkelia blazor.webassembly.js
│   ├── appsettings.json        ← API adresai, KOKIUS MATO NARŠYKLĖ
│   └── app.css
├── nginx.conf                  ← teikia statinius failus; nežinomi keliai → index.html
└── Dockerfile                  ← build su .NET SDK, vykdymas su nginx
```

## Paleidimas per Docker

Iš aplanko `student-docker-lab-plus-mssql`:

```bash
docker-compose -f docker-compose.infra.yml up -d
docker-compose up --build
```

Atidarykite **http://localhost:6041**. Pirmas įkėlimas užtrunka kelias sekundes (atsisiunčiamas .NET runtime),
vėliau failai imami iš naršyklės talpyklos.

## Paleidimas lokaliai (dotnet run)

API turi veikti; adresai nurodyti `wwwroot/appsettings.json`.

```bash
dotnet run
```

Atidarykite **http://localhost:6041**. Pasirinkimas **PHP (XAMPP)** kviečia `http://localhost:8080/simpleStudentApi/`
tiesiai iš naršyklės (PHP API jau siunčia CORS antraštes). Jei jūsų XAMPP Apache naudoja kitą prievadą ar
katalogą, pakeiskite tą `Url` faile `wwwroot/appsettings.json` (pvz. `http://localhost/simpleStudentApi/`
prievadui 80); Docker'yje po to perbuildinkite image'ą, nes failas įdedamas į jį.

## Problemų sprendimas

| Problema | Sprendimas |
|---|---|
| „Cannot reach the API: TypeError: Failed to fetch“ | API neveikia **arba** neleidžia CORS – žr. F12 → Console: CORS klaida nurodo, kurios antraštės trūksta |
| CORS klaida tik su .NET API | API image'as senas – perbuildinkite: `docker-compose up --build simplestudentapi` |
| Adresas su `simplestudentapi:8080` neveikia | šis vardas egzistuoja tik Docker viduje; naršyklei reikia `localhost:6001` |
| Tuščias puslapis, „Loading the .NET runtime…“ nedingsta | F12 → Console; dažniausiai nepavyko atsisiųsti `_framework/*` failų – perbuildinkite image'ą |
| Pakeistas `wwwroot/appsettings.json` neveikia | naršyklė jį laiko talpykloje – perkraukite su Ctrl+F5 (Cmd+Shift+R) |
