<?php
/**
 * انسخ الملف إلى config.local.php ولا ترفعه إلى GitHub.
 * يمكن بدل ذلك ضبط القيم كمتغيرات بيئة على الخادم.
 */

define('GPSQ_ADMIN_PASSWORD', 'CHANGE_WITH_A_STRONG_ADMIN_PASSWORD');
define('GPSQ_API_KEY', 'CHANGE_WITH_A_RANDOM_64_CHAR_ADMIN_API_KEY');
define('GPSQ_HMAC_SECRET', 'CHANGE_WITH_A_DIFFERENT_RANDOM_64_CHAR_HMAC_SECRET');

// قاعدة البيانات خارج public لحمايتها من التنزيل المباشر.
define('DB_PATH', dirname(__DIR__, 2) . '/data/gpsq.sqlite');
