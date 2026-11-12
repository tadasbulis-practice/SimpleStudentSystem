<?php defined('APP_ROOT') || exit('No direct access.'); ?>
<?php /** @var array|null $student @var array $fields */ ?>
<h1>Student details</h1>
<?php if (!empty($student)): ?>
    <?php foreach ($fields as $name => $f): ?>
        <div class="row"><span class="label"><?= h(OpenApi::label($name)) ?>:</span> <?= h((string)($student[$name] ?? '')) ?></div>
    <?php endforeach; ?>
    <p><a class="btn btn-edit" href="?page=edit&id=<?= (int)$student['id'] ?>">Edit</a></p>
<?php endif; ?>
<p class="hint"><code>GetStudent</code> → GET /api/students/{id}</p>
