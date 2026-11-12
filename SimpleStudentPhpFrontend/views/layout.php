<?php defined('APP_ROOT') || exit('No direct access.'); ?>
<?php /** @var string $view */ ?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Students – PHP frontend</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="card">
    <nav>
        <span class="tech">PHP <?= h(PHP_VERSION) ?></span>
        <a href="?page=students">Students</a>
        <a href="?page=info">API info</a>
        <a href="?page=operations">API operations</a>
        <a href="<?= h($apiPublicUrl) ?>/swagger" target="_blank">Swagger UI ↗</a>
        <a href="<?= h($dotnetUrl) ?>/Students" target="_blank">.NET frontend ↗</a>
    </nav>

    <?php if ($flash): ?><p class="ok-msg"><?= h($flash) ?></p><?php endif; ?>
    <?php if ($error): ?><p class="error">Error: <?= h($error) ?></p><?php endif; ?>

    <?php require $view; ?>

    <div class="meta">
        Contract: <?= h($spec->title()) ?> <?= h($spec->version()) ?> · loaded from <code><?= h($spec->source()) ?></code><br>
        This page has no hard-coded URLs or fields – they come from swagger.json.
    </div>
</div>
</body>
</html>
