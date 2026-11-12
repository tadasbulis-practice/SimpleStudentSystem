<?php
declare(strict_types=1);

/*
 * SimpleStudentPhpFrontend – Students CRUD written in plain PHP.
 *
 * Works the same way in:
 *   - XAMPP:   copy this whole folder to htdocs/  →  http://localhost/simpleStudentClient/
 *   - Docker:  docker-compose up --build          →  http://localhost:6021/
 *   - PHP CLI: php -S localhost:6021              →  http://localhost:6021/
 * The API address is set in config.php.
 *
 * It does not know the API's URLs or fields in advance. On every request it reads the API's
 * OpenAPI document (swagger.json) and:
 *   - calls endpoints by operationId  (lib/ApiClient.php)
 *   - builds the table and form from the Student schema  (lib/Form.php)
 *
 * Pages:  ?page=students (default) | student&id= | create | edit&id= | info | operations
 */

const APP_ROOT = __DIR__;                      // files in lib/ and views/ refuse to run without it

require_once APP_ROOT . '/lib/OpenApi.php';
require_once APP_ROOT . '/lib/ApiClient.php';
require_once APP_ROOT . '/lib/Form.php';

$config       = require APP_ROOT . '/config.php';
$apiBaseUrl   = $config['apiBaseUrl'];
$apiPublicUrl = $config['apiPublicUrl'];
$dotnetUrl    = $config['dotnetFrontendUrl'];

$spec   = OpenApi::load("$apiBaseUrl/swagger/v1/swagger.json", APP_ROOT . '/openapi/swagger.json');
$api    = new ApiClient($spec, $apiBaseUrl);
$fields = $spec->fields('Student');            // field list + rules come from the contract

$page    = $_GET['page'] ?? 'students';
$id      = isset($_GET['id']) ? (int)$_GET['id'] : null;
$error   = null;
$errors  = [];                                 // field errors from a 400 response
$flash   = $_GET['msg'] ?? null;

function redirect(string $query): never
{
    header('Location: ?' . $query);
    exit;
}

function describe(ApiException $e): string
{
    return match (true) {
        $e->status === 0   => $e->getMessage(),
        $e->status === 400 => 'Validation failed – see the fields below.',
        $e->status === 404 => 'Student not found (404).',
        default            => "API returned HTTP {$e->status}.",
    };
}

// ── POST actions (create, update, delete) ────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';
    $data   = Form::typed($fields, $_POST['data'] ?? []);
    try {
        if ($action === 'create') {
            $created = $api->call('CreateStudent', [], $data);                  // POST /api/students
            redirect('page=students&msg=' . urlencode("Created student #{$created['id']}"));
        }
        if ($action === 'update') {
            $api->call('UpdateStudent', ['id' => $id], $data + ['id' => $id]); // PUT /api/students/{id}
            redirect('page=students&msg=' . urlencode("Updated student #$id"));
        }
        if ($action === 'delete') {
            $api->call('DeleteStudent', ['id' => $id]);                         // DELETE /api/students/{id}
            redirect('page=students&msg=' . urlencode("Deleted student #$id"));
        }
    } catch (ApiException $e) {
        $error  = describe($e);
        $errors = $e->fieldErrors();
        $values = $data;                        // keep what the user typed
        $page   = $action === 'update' ? 'edit' : ($action === 'create' ? 'create' : 'students');
    }
}

// ── GET pages ────────────────────────────────────────────────────────────────
try {
    switch ($page) {
        case 'student':
        case 'edit':
            $student = $api->call('GetStudent', ['id' => $id]);                 // GET /api/students/{id}
            $values  = $values ?? $student;
            break;
        case 'create':
            $values = $values ?? [];
            break;
        case 'info':
            $info = $api->call('GetInfo');                                      // GET /api/info
            break;
        case 'operations':
            break;
        default:
            $page = 'students';
            $students = $api->call('GetStudents');                              // GET /api/students
    }
} catch (ApiException $e) {
    $error = $error ?? describe($e);
    $students = $students ?? [];
}

$view = APP_ROOT . "/views/$page.php";
require APP_ROOT . '/views/layout.php';
