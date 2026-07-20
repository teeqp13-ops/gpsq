<?php
/**
 * نموذج ملف الإعدادات المحلي (config.local.php)
 *
 * انسخ هذا الملف إلى config.local.php وعدّل القيم حسب بيئتك.
 * لا تضف config.local.php إلى git أبداً (مضمّن في .gitignore).
 *
 * طريقة الاستخدام:
 *   cp server/public/api/config.sample.php server/public/api/config.local.php
 *   ثم عدّل القيم في config.local.php
 */

// مفتاح API المستخدم للتحقق من طلبات التفعيل
define('GPSQ_API_KEY', 'ضع-مفتاح-API-هنا');

// كلمة مرور لوحة الإدارة
define('GPSQ_ADMIN_PASSWORD', 'ضع-كلمة-مرور-قوية-هنا');

// (اختياري) مسار ملف قاعدة بيانات SQLite
// define('DB_PATH', __DIR__ . '/../../../gpsq.db');
