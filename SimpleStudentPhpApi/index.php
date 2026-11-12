<?php
declare(strict_types=1);

/*
 * SimpleStudentPhpApi – the same Students REST API as SimpleStudentApi (.NET), written in plain PHP.
 *
 *   Contract:  openapi/openapi.json  (same paths, models and status codes as the .NET API)
 *   Database:  MySQL/MariaDB or SQL Server – chosen in config.php
 *
 * Runs the same way in:
 *   XAMPP:   copy this folder to htdocs/   → http://localhost/simpleStudentApi/swagger
 *   Docker:  docker-compose up --build     → http://localhost:6002/swagger
 *   PHP CLI: php -S localhost:6002 index.php
 */

const APP_ROOT = __DIR__;

// php -S index.php: let the built-in server deliver real files (swagger-ui/*.js, *.css) itself
if (PHP_SAPI === 'cli-server' && is_file(__DIR__ . parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH))) {
    return false;
}

require_once APP_ROOT . '/lib/Http.php';
require_once APP_ROOT . '/lib/Database.php';
require_once APP_ROOT . '/lib/StudentRepository.php';
require_once APP_ROOT . '/lib/Validator.php';

$config  = require APP_ROOT . '/config.php';
$openApi = json_decode((string)file_get_contents(APP_ROOT . '/openapi/openapi.json'), true);

Http::cors();

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$route  = Http::route();
$base   = Http::basePath();

// ── Swagger UI and the contract ──────────────────────────────────────────────
if ($route === '/') {
    header('Location: ' . $base . '/swagger');
    exit;
}
if ($route === '/swagger/v1/swagger.json') {
    // Same URL as the .NET API, so every client finds the contract in the same place.
    // "servers" tells Swagger UI where this API lives (important in an XAMPP subfolder).
    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $openApi['servers'] = [['url' => $scheme . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost') . $base]];
    Http::json(200, $openApi);
}
if ($route === '/swagger' || $route === '/swagger/index.html') {
    require APP_ROOT . '/lib/swagger-ui.php';
    exit;
}

// ── API ──────────────────────────────────────────────────────────────────────
try {
    if ($route === '/api/info' && $method === 'GET') {
        Http::json(200, [
            'service'      => 'SimpleStudentPhpApi',
            'version'      => '1.2',
            'status'       => 'ok',
            'message'      => 'Student CRUD API in PHP ' . PHP_VERSION . ' (database: ' . $config['database']['driver'] . ')',
            'environment'  => $config['environment'],
            'endpoints'    => ['/api/students', '/api/students/{id}', '/api/faculty', '/swagger'],
            'timestampUtc' => gmdate('Y-m-d\TH:i:s\Z'),
        ]);
    }

    // Unknown URL → 404 before we touch the database
    $known = $route === '/api/students' || $route === '/api/faculty' || preg_match('#^/api/students/\d+$#', $route);
    if (!$known) {
        Http::problem(404, "No endpoint $method $route", ['detail' => 'See ' . $base . '/swagger for all endpoints.']);
    }

    // Everything below needs the database
    $repo      = new StudentRepository(Database::connect($config['database']));
    $validator = new Validator($openApi);

    // GET /api/students  ·  POST /api/students
    if ($route === '/api/students') {
        if ($method === 'GET') {
            Http::json(200, $repo->all());                                            // GetStudents
        }
        if ($method === 'POST') {                                                     // CreateStudent
            $body = Http::jsonBody() ?? Http::problem(400, 'The request body must be a JSON object.');
            $errors = $validator->validate('Student', $body);
            if ($errors) {
                Http::validationProblem($errors);
            }
            $created = $repo->create($body);
            header('Location: ' . $base . '/api/students/' . $created['id']);
            Http::json(201, $created);
        }
    }

    // GET · PUT · DELETE /api/students/{id}
    if (preg_match('#^/api/students/(\d+)$#', $route, $m)) {
        $id = (int)$m[1];
        if ($method === 'GET') {                                                      // GetStudent
            $student = $repo->find($id);
            $student ? Http::json(200, $student) : Http::problem(404, 'Not Found');
        }
        if ($method === 'PUT') {                                                      // UpdateStudent
            $body = Http::jsonBody() ?? Http::problem(400, 'The request body must be a JSON object.');
            $errors = $validator->validate('Student', $body);
            if ($errors) {
                Http::validationProblem($errors);
            }
            $updated = $repo->update($id, $body);
            $updated ? Http::json(200, $updated) : Http::problem(404, 'Not Found');
        }
        if ($method === 'DELETE') {                                                   // DeleteStudent
            $repo->delete($id) ? Http::noContent() : Http::problem(404, 'Not Found');
        }
    }

    // GET /api/faculty – students grouped by study program + enrollment year (same logic as .NET)
    if ($route === '/api/faculty' && $method === 'GET') {                             // GetFaculty
        $groups = [];
        foreach ($repo->all() as $s) {
            $groups[$s['studyProgram'] . '|' . $s['enrollmentYear']][] = $s;
        }
        $result = [];
        foreach ($groups as $students) {
            usort($students, fn($a, $b) => [$a['lastName'], $a['firstName']] <=> [$b['lastName'], $b['firstName']]);
            $program = $students[0]['studyProgram'];
            $year    = $students[0]['enrollmentYear'];
            $prefix  = implode('', array_map(fn($w) => mb_strtoupper(mb_substr($w, 0, 1)), preg_split('/\s+/', trim($program))));
            $result[] = ['code' => sprintf('%s-%02d', $prefix, $year % 100), 'studyProgram' => $program,
                         'enrollmentYear' => $year, 'students' => $students];
        }
        usort($result, fn($a, $b) => [$a['studyProgram'], $a['enrollmentYear']] <=> [$b['studyProgram'], $b['enrollmentYear']]);
        Http::json(200, ['name' => 'Faculty of Technology', 'groups' => $result]);
    }

    // Known URL, but this HTTP method is not supported (e.g. DELETE /api/students)
    Http::problem(405, "Method $method is not allowed for $route", ['detail' => 'See ' . $base . '/swagger for all endpoints.']);
} catch (PDOException $e) {
    $hint = str_contains($e->getMessage(), 'Students')
        ? 'Has the table been created? Run database/' . $config['database']['driver'] . '/create.sql.'
        : 'Check the database settings in config.php and that the database server is running.';
    Http::problem(500, 'Database error', $config['debug'] ? ['detail' => $e->getMessage(), 'hint' => $hint] : []);
} catch (Throwable $e) {
    Http::problem(500, 'Server error', $config['debug'] ? ['detail' => $e->getMessage()] : []);
}
