<?php
declare(strict_types=1);

defined('APP_ROOT') || exit('No direct access.');

/**
 * Reads the API's OpenAPI document (swagger.json) and answers questions about it:
 *   - which HTTP method and path belong to an operationId  (e.g. "CreateStudent" → POST /api/students)
 *   - which fields a schema has and what rules apply        (e.g. Student.email: required, format email)
 *
 * Nothing about the Student API is hard-coded here. Point it at another OpenAPI document
 * and it works the same way – that is the point of having a contract.
 */
final class OpenApi
{
    private array $doc;

    private function __construct(array $doc)
    {
        $this->doc = $doc;
    }

    /**
     * Downloads swagger.json from the running API (cached for a few seconds),
     * falls back to the copy in openapi/swagger.json when the API is not reachable.
     */
    public static function load(string $specUrl, string $fallbackFile, int $cacheSeconds = 10): self
    {
        $cacheFile = sys_get_temp_dir() . '/openapi-' . md5($specUrl) . '.json';

        if (is_file($cacheFile) && time() - filemtime($cacheFile) < $cacheSeconds) {
            $doc = json_decode((string)file_get_contents($cacheFile), true);
            $doc['x-loaded-from'] = $specUrl;
            return new self($doc);
        }

        $context = stream_context_create(['http' => ['timeout' => 3, 'ignore_errors' => true]]);
        $json = @file_get_contents($specUrl, false, $context);
        $doc = is_string($json) ? json_decode($json, true) : null;

        if (is_array($doc) && isset($doc['paths'])) {
            file_put_contents($cacheFile, $json);
            $doc['x-loaded-from'] = $specUrl;
            return new self($doc);
        }

        $doc = json_decode((string)file_get_contents($fallbackFile), true);
        $doc['x-loaded-from'] = $fallbackFile . ' (API not reachable – using the saved copy)';
        return new self($doc);
    }

    public function title(): string   { return $this->doc['info']['title'] ?? 'API'; }
    public function version(): string { return $this->doc['info']['version'] ?? ''; }
    public function source(): string  { return $this->doc['x-loaded-from'] ?? ''; }

    /**
     * All operations as a flat list:
     * [ ['operationId' => 'GetStudents', 'method' => 'GET', 'path' => '/api/students', 'summary' => ..., ...], ... ]
     */
    public function operations(): array
    {
        $result = [];
        foreach ($this->doc['paths'] as $path => $methods) {
            foreach ($methods as $method => $op) {
                if (!is_array($op) || !isset($op['operationId'])) {
                    continue;
                }
                $result[] = [
                    'operationId' => $op['operationId'],
                    'method'      => strtoupper($method),
                    'path'        => $path,
                    'summary'     => $op['summary'] ?? '',
                    'description' => $op['description'] ?? '',
                    'tags'        => $op['tags'] ?? [],
                    'parameters'  => $op['parameters'] ?? [],
                    'hasBody'     => isset($op['requestBody']),
                    'responses'   => array_keys($op['responses'] ?? []),
                ];
            }
        }
        return $result;
    }

    public function operation(string $operationId): array
    {
        foreach ($this->operations() as $op) {
            if ($op['operationId'] === $operationId) {
                return $op;
            }
        }
        throw new InvalidArgumentException("Operation '$operationId' is not in the OpenAPI document.");
    }

    /**
     * Fields of a schema, e.g. fields('Student'):
     * [ 'firstName' => ['type' => 'string', 'required' => true, 'maxLength' => 100, 'readOnly' => false, ...], ... ]
     */
    public function fields(string $schemaName): array
    {
        $schema = $this->doc['components']['schemas'][$schemaName] ?? null;
        if ($schema === null) {
            throw new InvalidArgumentException("Schema '$schemaName' is not in the OpenAPI document.");
        }
        $required = $schema['required'] ?? [];
        $fields = [];
        foreach ($schema['properties'] ?? [] as $name => $p) {
            $fields[$name] = [
                'type'        => $p['type'] ?? 'string',
                'format'      => $p['format'] ?? null,
                'required'    => in_array($name, $required, true),
                'readOnly'    => (bool)($p['readOnly'] ?? false),
                'maxLength'   => $p['maxLength'] ?? null,
                'minimum'     => $p['minimum'] ?? null,
                'maximum'     => $p['maximum'] ?? null,
                'description' => $p['description'] ?? '',
                'example'     => $p['example'] ?? null,
            ];
        }
        return $fields;
    }

    /** "enrollmentYear" → "Enrollment year" (labels come from the schema too). */
    public static function label(string $name): string
    {
        $words = preg_replace('/(?<!^)([A-Z])/', ' $1', $name);
        return ucfirst(strtolower($words));
    }
}
