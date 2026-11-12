<?php
declare(strict_types=1);

defined('APP_ROOT') || exit('No direct access.');

require_once __DIR__ . '/OpenApi.php';

/** Thrown for every HTTP status >= 400. Holds the problem details the API returned. */
final class ApiException extends RuntimeException
{
    public function __construct(public readonly int $status, public readonly array $problem = [], string $message = '')
    {
        parent::__construct($message !== '' ? $message : "API returned HTTP $status");
    }

    /** Field errors from a 400 ValidationProblem: ['firstName' => ['First name is required.'], ...] */
    public function fieldErrors(): array
    {
        return $this->problem['errors'] ?? [];
    }
}

/**
 * Generic API client: you call an operation BY NAME (operationId from swagger.json),
 * the client looks up the method and URL in the OpenAPI document.
 *
 *   $api->call('GetStudents');
 *   $api->call('GetStudent',    ['id' => 5]);
 *   $api->call('CreateStudent', [],          ['firstName' => 'Jonas', ...]);
 *   $api->call('UpdateStudent', ['id' => 5], [...]);
 *   $api->call('DeleteStudent', ['id' => 5]);
 *
 * No URL is written by hand anywhere in the PHP frontend.
 */
final class ApiClient
{
    public function __construct(private readonly OpenApi $spec, private readonly string $baseUrl)
    {
    }

    public function spec(): OpenApi
    {
        return $this->spec;
    }

    /**
     * @param array      $params path and query parameters, e.g. ['id' => 5] or ['program' => 'CS']
     * @param array|null $body   request body (sent as JSON)
     * @return mixed decoded JSON response (null for 204 No Content)
     */
    public function call(string $operationId, array $params = [], ?array $body = null): mixed
    {
        $op = $this->spec->operation($operationId);

        // 1. Build the URL from the path template:  /api/students/{id}  →  /api/students/5
        $path = $op['path'];
        $query = [];
        foreach ($op['parameters'] as $p) {
            $name = $p['name'];
            if (!array_key_exists($name, $params)) {
                if (!empty($p['required'])) {
                    throw new InvalidArgumentException("Parameter '$name' is required for $operationId.");
                }
                continue;
            }
            if (($p['in'] ?? '') === 'path') {
                $path = str_replace('{' . $name . '}', rawurlencode((string)$params[$name]), $path);
            } elseif (($p['in'] ?? '') === 'query') {
                $query[$name] = $params[$name];
            }
        }
        $url = rtrim($this->baseUrl, '/') . $path . ($query ? '?' . http_build_query($query) : '');

        // 2. Send the request (plain PHP streams – no extensions or Composer packages needed)
        $headers = ['Accept: application/json'];
        $content = null;
        if ($body !== null) {
            $headers[] = 'Content-Type: application/json';
            $content = json_encode($body, JSON_UNESCAPED_UNICODE);
        }
        $context = stream_context_create(['http' => [
            'method'        => $op['method'],
            'header'        => implode("\r\n", $headers),
            'content'       => $content,
            'timeout'       => 10,
            'ignore_errors' => true,          // read the body of 4xx/5xx responses too
        ]]);

        $raw = @file_get_contents($url, false, $context);
        if ($raw === false) {
            throw new ApiException(0, [], "Cannot reach the API at {$this->baseUrl}");
        }

        // 3. Read the status code from the response headers ("HTTP/1.1 201 Created")
        $status = 0;
        $responseHeaders = function_exists('http_get_last_response_headers')
            ? (http_get_last_response_headers() ?? [])      // PHP 8.4+
            : ($http_response_header ?? []);                 // PHP 8.3
        foreach ($responseHeaders as $line) {
            if (preg_match('#^HTTP/\S+\s+(\d{3})#', $line, $m)) {
                $status = (int)$m[1];
            }
        }

        $data = $raw === '' ? null : json_decode($raw, true);
        if ($status >= 400) {
            throw new ApiException($status, is_array($data) ? $data : []);
        }
        return $data;
    }
}
