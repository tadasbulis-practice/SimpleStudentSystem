<?php defined('APP_ROOT') || exit('No direct access.'); ?>
<?php /** @var array $students @var array $fields */ ?>
<h1>Students</h1>
<a class="btn btn-create" href="?page=create">+ Add Student</a>

<?php if (!$students && !$error): ?>
    <p class="empty">No students found. Add one above!</p>
<?php else: ?>
<table>
    <thead>
    <tr>
        <?php foreach ($fields as $name => $f): ?>
            <th><?= h(OpenApi::label($name)) ?></th>
        <?php endforeach; ?>
        <th>Actions</th>
    </tr>
    </thead>
    <tbody>
    <?php foreach ($students as $s): ?>
        <tr>
            <?php foreach ($fields as $name => $f): ?>
                <td><?= h((string)($s[$name] ?? '')) ?></td>
            <?php endforeach; ?>
            <td class="actions">
                <a class="btn btn-view" href="?page=student&id=<?= (int)$s['id'] ?>">View</a>
                <a class="btn btn-edit" href="?page=edit&id=<?= (int)$s['id'] ?>">Edit</a>
                <form method="post" action="?id=<?= (int)$s['id'] ?>" onsubmit="return confirm('Delete student #<?= (int)$s['id'] ?>?')">
                    <input type="hidden" name="action" value="delete">
                    <button class="btn btn-delete" type="submit">Delete</button>
                </form>
            </td>
        </tr>
    <?php endforeach; ?>
    </tbody>
</table>
<?php endif; ?>
<p class="hint">Columns are generated from <code>components.schemas.Student</code>. Data: <code>GetStudents</code> → GET /api/students.</p>
