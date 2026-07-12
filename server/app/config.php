<?php
declare(strict_types=1);

return [
    'app_name' => 'Wolfox GPS',
    'timezone' => 'Asia/Riyadh',

    // Keep the database and installation lock outside server/public.
    'db_path' => dirname(__DIR__) . '/gpsplus-private/database.sqlite',
    'install_lock' => dirname(__DIR__) . '/gpsplus-private/installed.lock',

    'admin_username' => getenv('GPS_ADMIN_USERNAME') ?: 'admin',
    'admin_password_hash' => getenv('GPS_ADMIN_PASSWORD_HASH') ?: '$2y$10$H3Y6AHu79fhhXJEUmEWn2exJ1AfvV9kvY3Pg3hgp0vzYQg3jEnw5u',

    // Do not store the production API key in a public repository.
    'api_key' => getenv('GPS_API_KEY') ?: '',
    'session_name' => 'GPSPLUS_ADMIN',
];
