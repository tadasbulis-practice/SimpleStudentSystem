<?php defined('APP_ROOT') || exit('No direct access.');
/** @var string $base */
// Static files live next to index.php – without the "/index.php" part of the base path.
$assets = preg_replace('#/index\\.php$#', '', $base) . '/swagger-ui';
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>SimpleStudentPhpApi – Swagger</title>
    <!-- Swagger UI files are bundled in swagger-ui/ (works without internet). The contract comes from this API. -->
    <link rel="stylesheet" href="<?= htmlspecialchars($assets) ?>/swagger-ui.css">
    <link rel="icon" href="<?= htmlspecialchars($assets) ?>/favicon-32x32.png">
    <style>
        body { margin: 0; }
        .php-banner { background: #777bb4; color: #fff; font: bold 14px Arial, sans-serif; padding: 8px 20px; }
    </style>
</head>
<body>
<div class="php-banner">PHP <?= htmlspecialchars(PHP_VERSION) ?> implementation of the SimpleStudentApi contract</div>
<div id="swagger-ui"></div>
<script src="<?= htmlspecialchars($assets) ?>/swagger-ui-bundle.js"></script>
<script>
    SwaggerUIBundle({
        url: <?= json_encode($base . '/swagger/v1/swagger.json') ?>,
        dom_id: '#swagger-ui'
    });
</script>
</body>
</html>
