<?php defined('APP_ROOT') || exit('No direct access.'); ?>
<?php $action = 'update'; ?>
<h1>Edit Student</h1>
<div class="id-badge">ID: <?= (int)$id ?></div>
<?php require __DIR__ . '/_form.php'; ?>
<p class="hint">Submit: <code>UpdateStudent</code> → PUT /api/students/{id}</p>
