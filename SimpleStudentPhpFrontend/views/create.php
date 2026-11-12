<?php defined('APP_ROOT') || exit('No direct access.'); ?>
<?php $action = 'create'; ?>
<h1>Add New Student</h1>
<?php require __DIR__ . '/_form.php'; ?>
<p class="hint">Form fields and rules are generated from the Student schema. Submit: <code>CreateStudent</code> → POST /api/students</p>
