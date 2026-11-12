<?php
declare(strict_types=1);

defined('APP_ROOT') || exit('No direct access.');

/** Small helpers for JSON responses in the same format as ASP.NET Core. */
final class Http
{
    public static function json(int $status, mixed $data): never
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }

    public static function noContent(): never
    {
        http_response_code(204);
        exit;
    }

    /** RFC 9457 problem details – same shape as Results.ValidationProblem() in .NET */
    public static function validationProblem(array $errors): never
    {
        self::problem(400, 'One or more validation errors occurred.', ['errors' => $errors],
            'https://tools.ietf.org/html/rfc9110#section-15.5.1');
    }

    public static function problem(int $status, string $title, array $extra = [], string $type = ''): never
    {
        http_response_code($status);
        header('Content-Type: application/problem+json; charset=utf-8');
        $body = ['type' => $type ?: "https://httpstatuses.io/$status", 'title' => $title, 'status' => $status] + $extra;
        echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }

    /** Reads a JSON request body. Returns null if the body is not a JSON object. */
    public static function jsonBody(): ?array
    {
        $data = json_decode((string)file_get_contents('php://input'), true);
        return is_array($data) ? $data : null;
    }

    /**
     * Path of the request relative to this application, e.g. "/api/students/5".
     * Works with:  XAMPP + .htaccess (/simpleStudentApi/api/students),
     *              without rewrite   (/simpleStudentApi/index.php/api/students),
     *              php -S index.php  and the Docker image (/api/students).
     */
    public static function route(): string
    {
        if (!empty($_SERVER['PATH_INFO'])) {
            return '/' . trim($_SERVER['PATH_INFO'], '/');
        }
        $path   = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
        $script = str_replace('\\', '/', $_SERVER['SCRIPT_NAME'] ?? '');
        if (basename($script) === 'index.php') {
            // strip "/simpleStudentApi/index.php" or "/simpleStudentApi" from the front
            foreach ([$script, rtrim(dirname($script), '/.')] as $prefix) {
                if ($prefix !== '' && str_starts_with($path, $prefix)) {
                    $path = substr($path, strlen($prefix));
                    break;
                }
            }
        }
        return '/' . trim($path, '/');
    }

    /**
     * Prefix of every URL of this API:
     *   "/simpleStudentApi"            XAMPP with .htaccess (mod_rewrite)
     *   "/simpleStudentApi/index.php"  XAMPP without mod_rewrite (URLs like .../index.php/api/students)
     *   ""                             Docker and php -S
     */
    public static function basePath(): string
    {
        $script = $_SERVER['SCRIPT_NAME'] ?? '/index.php';
        if (basename($script) !== 'index.php') {
            return '';                       // php -S with router script (it sets SCRIPT_NAME to the URL)
        }
        $path   = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
        if (str_starts_with($path, $script) || !self::hasRewrite()) {
            return rtrim($script, '/');      // URLs must contain index.php
        }
        return rtrim(str_replace('\\', '/', dirname($script)), '/.');
    }

    /** Is Apache's mod_rewrite active (needed for "pretty" URLs without index.php)? */
    private static function hasRewrite(): bool
    {
        // Outside Apache (php -S) every request reaches index.php anyway
        return !function_exists('apache_get_modules') || in_array('mod_rewrite', apache_get_modules(), true);
    }

    /** Allow browser apps on other origins (JavaScript, Swagger UI elsewhere) to call the API. */
    public static function cors(): void
    {
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
        header('Access-Control-Allow-Headers: Content-Type, Accept');
        if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
            self::noContent();
        }
    }
}
