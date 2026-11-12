<?php defined('APP_ROOT') || exit('No direct access.'); ?>
<?php /** @var array $info */ ?>
<h1>API info</h1>
<?php foreach (($info ?? []) as $k => $v): ?>
    <div class="row"><span class="label"><?= h(OpenApi::label($k)) ?>:</span> <?= h(is_array($v) ? implode(', ', $v) : (string)$v) ?></div>
<?php endforeach; ?>
<p class="hint"><code>GetInfo</code> → GET /api/info</p>
