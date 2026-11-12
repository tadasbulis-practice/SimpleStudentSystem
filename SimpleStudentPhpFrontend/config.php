<?php
declare(strict_types=1);

defined('APP_ROOT') || exit('No direct access.');

/*
 * Where is the API?
 *
 * Docker:  set by environment variables in docker-compose.yml – nothing to change here.
 * XAMPP:   the defaults below are used. The API must be reachable from your computer,
 *          e.g. the API container on http://localhost:6001 (docker-compose up -d simplestudentapi)
 *          or the API started with "dotnet run". Change the URLs if yours are different.
 *
 * Both APIs implement the same contract – switch the backend by changing only the URL:
 *   .NET API (Docker):  http://localhost:6001
 *   PHP API  (Docker):  http://localhost:6002
 *   PHP API  (XAMPP):   http://localhost/simpleStudentApi   (or :8080, depending on your XAMPP port)
 *   PHP API, no mod_rewrite: http://localhost/simpleStudentApi/index.php
 */
return [
    // Address PHP uses to call the API (server side)
    'apiBaseUrl'        => getenv('API_BASE_URL')        ?: 'http://localhost:6001',

    // Address your BROWSER uses for the "Swagger UI" link
    'apiPublicUrl'      => getenv('API_PUBLIC_URL')      ?: 'http://localhost:6001',

    // Link to the .NET frontend (only used in the menu)
    'dotnetFrontendUrl' => getenv('DOTNET_FRONTEND_URL') ?: 'http://localhost:6011',
];
