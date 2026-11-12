# SimpleStudentPhpFrontend

Students CRUD in plain **PHP 8.1+** (no Composer, no extensions). It reads the API's
OpenAPI document (`swagger.json`) and builds everything from it: URLs come from the
`operationId`, table columns and form fields come from the `Student` schema.

The folder is **flat**, so the same files work in XAMPP, Docker and the PHP built-in server.

```
SimpleStudentPhpFrontend/      ← copy this folder as it is
├── index.php                  ← the only page (router: ?page=students|student|create|edit|info|operations)
├── config.php                 ← API address  ← edit this for XAMPP if needed
├── style.css
├── lib/                       ← OpenApi.php, ApiClient.php, Form.php   (not reachable from the browser)
├── views/                     ← HTML templates                          (not reachable from the browser)
├── openapi/swagger.json       ← saved copy of the contract, used only when the API is down
├── .htaccess                  ← blocks lib/, views/, config.php (Apache: XAMPP and Docker)
└── Dockerfile
```

## 1. XAMPP (most common)

1. Start the API so it answers on **http://localhost:6001/swagger**, e.g.
   ```bash
   docker-compose -f docker-compose.infra.yml up -d     # SQL Server
   docker-compose up -d simplestudentapi                # API only
   ```
   (or run the API from Visual Studio / `dotnet run` – then check its port).
2. Copy the folder into `htdocs` and give it any name:
   - Windows: `C:\xampp\htdocs\simpleStudentClient\`
   - macOS:   `/Applications/XAMPP/xamppfiles/htdocs/simpleStudentClient/`
3. Open **http://localhost/simpleStudentClient/** (or `:8080` if your XAMPP Apache uses port 8080).
4. Different API address? Change `apiBaseUrl` in `config.php`.

> **macOS – "Access forbidden" / Error 403:** XAMPP's Apache runs as another user and must be
> able to read the files. Run once:
> `chmod -R a+rX /Applications/XAMPP/xamppfiles/htdocs/simpleStudentClient`

## 2. Docker

Nothing to configure – `docker-compose.yml` passes the addresses as environment variables
(`API_BASE_URL=http://simplestudentapi:8080` inside the Docker network):

```bash
docker-compose up --build
```

Open **http://localhost:6021/**.

## 3. PHP built-in server (no Apache)

```bash
cd SimpleStudentPhpFrontend
php -S localhost:6021
```

## How it works (short)

```php
$spec = OpenApi::load("$apiBaseUrl/swagger/v1/swagger.json", ...);  // read the contract
$api  = new ApiClient($spec, $apiBaseUrl);

$api->call('GetStudents');                       // GET    /api/students
$api->call('CreateStudent', [], $data);          // POST   /api/students
$api->call('UpdateStudent', ['id' => 5], $data); // PUT    /api/students/5
$api->call('DeleteStudent', ['id' => 5]);        // DELETE /api/students/5

$fields = $spec->fields('Student');              // columns, inputs, validation rules
```

Pages to show in class:

| URL | What it shows |
|-----|---------------|
| `/` | students table – columns generated from the schema |
| `?page=create` | form – inputs and rules (required, maxlength, email, min/max) from the schema |
| `?page=operations` | every operation and field rule, read live from swagger.json |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| 403 Access forbidden (macOS XAMPP) | `chmod -R a+rX …/htdocs/simpleStudentClient` |
| "Cannot reach the API" | the API is not running on the address in `config.php` |
| footer says "using the saved copy" | PHP could not download swagger.json – same cause as above |
| "No direct access." | you opened a file in `lib/` or `views/` – open `index.php` (the folder URL) instead |
| blank page / syntax error | PHP older than 8.1 – update XAMPP |
