<?php
declare(strict_types=1);

return [
    'app_name' => 'Wolfox GPS',
    'timezone' => 'Asia/Riyadh',

    // Keep private runtime files outside the public web directory.
    'db_path' => dirname(__DIR__) . '/gpsplus-private/database.sqlite',
    'install_lock' => dirname(__DIR__) . '/gpsplus-private/installed.lock',

    // Production credentials must be supplied by the hosting environment.
    'admin_username' => getenv('GPS_ADMIN_USERNAME') ?: 'admin',
    'admin_password_hash' => getenv('GPS_ADMIN_PASSWORD_HASH') ?: '',
    'api_key' => getenv('GPS_API_KEY') ?: '',

    'session_name' => 'GPSPLUS_ADMIN',
];
