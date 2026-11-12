<?php
declare(strict_types=1);

defined('APP_ROOT') || exit('No direct access.');

/**
 * Builds HTML form inputs from an OpenAPI schema.
 * The rules come from swagger.json, which gets them from the C# attributes on the API model:
 *
 *   [Required]           → required
 *   [StringLength(100)]  → maxlength="100"
 *   [EmailAddress]       → type="email"
 *   [Range(2000, 2100)]  → type="number" min="2000" max="2100"
 *   [ReadOnly(true)]     → not editable (the database generates it)
 */
final class Form
{
    public static function input(string $name, array $field, mixed $value, array $errors = []): string
    {
        $id    = 'f_' . $name;
        $label = h(OpenApi::label($name));
        $attrs = ['id' => $id, 'name' => "data[$name]"];

        if ($field['type'] === 'integer' || $field['type'] === 'number') {
            $attrs['type'] = 'number';
            if ($field['minimum'] !== null) $attrs['min'] = $field['minimum'];
            if ($field['maximum'] !== null) $attrs['max'] = $field['maximum'];
        } elseif ($field['format'] === 'email') {
            $attrs['type'] = 'email';
        } elseif ($field['format'] === 'date') {
            $attrs['type'] = 'date';
        } else {
            $attrs['type'] = 'text';
        }
        if ($field['maxLength'] !== null) $attrs['maxlength'] = $field['maxLength'];
        if ($field['required'])           $attrs['required']  = 'required';
        if ($field['example'] !== null)   $attrs['placeholder'] = 'e.g. ' . $field['example'];
        $attrs['value'] = $value ?? '';

        $html = '';
        foreach ($attrs as $k => $v) {
            $html .= ' ' . $k . '="' . h((string)$v) . '"';
        }

        $rules = self::rules($field);
        $errorHtml = '';
        foreach ($errors as $msg) {
            $errorHtml .= '<div class="field-error">' . h($msg) . '</div>';
        }

        return <<<HTML
        <div class="field">
            <label for="$id">$label</label>
            <input$html>
            <div class="hint">$rules</div>
            $errorHtml
        </div>
        HTML;
    }

    /** Human-readable list of the rules taken from the schema – shown under each input. */
    public static function rules(array $field): string
    {
        $r = [];
        $r[] = $field['format'] ? "{$field['type']} ({$field['format']})" : $field['type'];
        if ($field['required'])           $r[] = 'required';
        if ($field['maxLength'] !== null) $r[] = "max {$field['maxLength']} chars";
        if ($field['minimum'] !== null && $field['maximum'] !== null) $r[] = "{$field['minimum']}–{$field['maximum']}";
        return h('from swagger.json: ' . implode(' · ', $r));
    }

    /** Converts posted strings to the JSON types the schema expects (integer, number, boolean). */
    public static function typed(array $fields, array $posted): array
    {
        $out = [];
        foreach ($fields as $name => $f) {
            if ($f['readOnly'] || !array_key_exists($name, $posted)) {
                continue;
            }
            $v = trim((string)$posted[$name]);
            $out[$name] = match ($f['type']) {
                'integer' => $v === '' ? 0 : (int)$v,
                'number'  => $v === '' ? 0 : (float)$v,
                'boolean' => in_array($v, ['1', 'true', 'on'], true),
                default   => $v,
            };
        }
        return $out;
    }
}

function h(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
