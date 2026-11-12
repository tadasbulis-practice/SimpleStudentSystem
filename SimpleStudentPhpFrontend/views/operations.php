<?php defined('APP_ROOT') || exit('No direct access.'); ?>
<?php /** @var OpenApi $spec */ ?>
<h1>API operations</h1>
<p>Everything this frontend can call, read live from <code>swagger.json</code>. The PHP code uses only the
<strong>operationId</strong> – method and URL are looked up here.</p>
<table>
    <thead><tr><th>operationId</th><th>Method</th><th>Path</th><th>Summary</th><th>Responses</th></tr></thead>
    <tbody>
    <?php foreach ($spec->operations() as $op): ?>
        <tr>
            <td><code><?= h($op['operationId']) ?></code></td>
            <td><span class="method m-<?= strtolower($op['method']) ?>"><?= h($op['method']) ?></span></td>
            <td><code><?= h($op['path']) ?></code></td>
            <td><?= h($op['summary']) ?></td>
            <td><?= h(implode(', ', $op['responses'])) ?></td>
        </tr>
    <?php endforeach; ?>
    </tbody>
</table>
<h2>Student schema</h2>
<table>
    <thead><tr><th>Field</th><th>Rules</th><th>Description</th></tr></thead>
    <tbody>
    <?php foreach ($fields as $name => $f): ?>
        <tr><td><code><?= h($name) ?></code></td><td><?= Form::rules($f) ?><?= $f['readOnly'] ? ' · read-only' : '' ?></td><td><?= h($f['description']) ?></td></tr>
    <?php endforeach; ?>
    </tbody>
</table>
