<?php
declare(strict_types=1);

return [
    'app_name' => 'Wolfox GPS',
    'timezone' => 'Asia/Riyadh',

    // Keep private runtime files outside the public web directory.
    'db_path' => dirname(__DIR__) . '/gpsplus-private/database.sqlite',
    'install_lock' => dirname(__DIR__) . '/gpsplus-private/installed.lock',

    'admin_username' => getenv('GPS_ADMIN_USERNAME') ?: 'admin',
    'admin_password_hash' => getenv('GPS_ADMIN_PASSWORD_HASH') ?: '$2y$10$H3Y6AHu79fhhXJEUmEWn2exJ1AfvV9kvY3Pg3hgp0vzYQg3jEnw5u',

    // The client and server must use the same key.
    'api_key' => getenv('GPS_API_KEY') ?: 'gps_c11532a714400a3f53a0dffd1ea723e2511ede6bdcb3be9b',
    'session_name' => 'GPSPLUS_ADMIN',
];
