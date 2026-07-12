<?php
declare(strict_types=1);
return [
    'app_name' => 'Wolfox GPS',
    'timezone' => 'Asia/Riyadh',
    'db_path' => dirname(__DIR__) . '/storage/database.sqlite',
    'install_lock' => dirname(__DIR__) . '/storage/installed.lock',
    'api_key' => getenv('GPS_API_KEY') ?: 'CHANGE_THIS_API_KEY',
    'session_name' => 'GPSPLUS_ADMIN',
];
