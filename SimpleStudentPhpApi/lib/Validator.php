<?php
declare(strict_types=1);

defined('APP_ROOT') || exit('No direct access.');

/**
 * Validates request bodies against a schema in openapi.json (contract-first).
 * The rules are NOT written in PHP – they come from components.schemas.Student:
 *   required, maxLength, format: email, minimum / maximum, readOnly.
 * Change the contract and the validation changes with it.
 */
final class Validator
{
    public function __construct(private readonly array $openApi)
    {
    }

    /**
     * @return array<string, string[]> field => messages (empty array = valid)
     */
    public function validate(string $schemaName, array $data): array
    {
        $schema   = $this->openApi['components']['schemas'][$schemaName];
        $required = $schema['required'] ?? [];
        $errors   = [];

        foreach ($schema['properties'] as $name => $rule) {
            if (!empty($rule['readOnly'])) {
                continue;                                    // e.g. id – the database sets it
            }
            $label = self::label($name);
            $value = $data[$name] ?? null;
            $type  = $rule['type'] ?? 'string';

            if ($type === 'string') {
                $text = is_scalar($value) ? trim((string)$value) : '';
                if (in_array($name, $required, true) && $text === '') {
                    $errors[$name][] = ($rule['format'] ?? '') === 'email' ? 'A valid email is required.' : "$label is required.";
                    continue;
                }
                if (($rule['format'] ?? '') === 'email' && $text !== '' && !filter_var($text, FILTER_VALIDATE_EMAIL)) {
                    $errors[$name][] = 'A valid email is required.';
                }
                if (isset($rule['maxLength']) && mb_strlen($text) > $rule['maxLength']) {
                    $errors[$name][] = "$label must be at most {$rule['maxLength']} characters.";
                }
            }

            if ($type === 'integer') {
                if (!is_int($value) && !(is_string($value) && preg_match('/^-?\d+$/', $value))) {
                    $errors[$name][] = "$label must be a whole number.";
                    continue;
                }
                $n = (int)$value;
                if (isset($rule['minimum'], $rule['maximum']) && ($n < $rule['minimum'] || $n > $rule['maximum'])) {
                    $errors[$name][] = "$label must be between {$rule['minimum']} and {$rule['maximum']}.";
                }
            }
        }
        return $errors;
    }

    /** "enrollmentYear" → "Enrollment year" */
    private static function label(string $name): string
    {
        return ucfirst(strtolower(preg_replace('/(?<!^)([A-Z])/', ' $1', $name)));
    }
}
