<?php
/**
 * إعدادات مشتركة لـ GPS Plus Server
 *
 * متغيرات البيئة المطلوبة عند النشر:
 *   GPSQ_API_KEY          — مفتاح API للتحقق من طلبات التفعيل
 *   GPSQ_ADMIN_PASSWORD   — كلمة مرور لوحة الإدارة
 *
 * يمكن إنشاء ملف config.local.php في نفس المجلد (غير مضاف إلى git)
 * لتعريف هذه الثوابت محلياً بدلاً من متغيرات البيئة.
 */

// تحميل الإعدادات المحلية إذا وُجدت (لبيئة التطوير فقط)
$_localCfg = __DIR__ . '/config.local.php';
if (file_exists($_localCfg)) {
    require_once $_localCfg;
}

// مفتاح API — يُقرأ من متغير البيئة أو من config.local.php
if (!defined('GPSQ_API_KEY')) {
    define('GPSQ_API_KEY', getenv('GPSQ_API_KEY') ?: '');
}

// كلمة مرور الإدارة — يُقرأ من متغير البيئة أو من config.local.php
if (!defined('GPSQ_ADMIN_PASSWORD')) {
    define('GPSQ_ADMIN_PASSWORD', getenv('GPSQ_ADMIN_PASSWORD') ?: '');
}

// مسار ملف قاعدة بيانات SQLite
// للتبديل إلى MySQL لاحقاً: اطّلع على دالة getDB() أدناه
if (!defined('DB_PATH')) {
    define('DB_PATH', __DIR__ . '/../../../gpsq.db');
}

// ============================================================
// دالة الاتصال بقاعدة البيانات (Singleton)
// ============================================================
function getDB(): PDO
{
    static $pdo = null;
    if ($pdo !== null) {
        return $pdo;
    }

    // SQLite (افتراضي)
    $pdo = new PDO('sqlite:' . DB_PATH);

    /*
     * MySQL alternative — فك التعليق وعدّل البيانات عند التبديل:
     * $pdo = new PDO(
     *     'mysql:host=127.0.0.1;dbname=gpsq;charset=utf8mb4',
     *     'db_user',
     *     'db_pass'
     * );
     */

    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

    // SQLite: تفعيل دعم المفاتيح الخارجية
    $pdo->exec('PRAGMA foreign_keys = ON');

    initSchema($pdo);

    return $pdo;
}

// ============================================================
// إنشاء الجداول عند أول تشغيل
// ============================================================
function initSchema(PDO $pdo): void
{
    // جدول الأكواد الرئيسي
    $pdo->exec("CREATE TABLE IF NOT EXISTS codes (
        code         TEXT PRIMARY KEY,
        status       TEXT NOT NULL DEFAULT 'unused',
        udid         TEXT,
        device_name  TEXT,
        ios_version  TEXT,
        app_version  TEXT,
        created_at   TEXT NOT NULL DEFAULT (datetime('now')),
        activated_at TEXT
    )");

    // جدول الأجهزة — لدعم أجهزة متعددة لكل كود مستقبلاً
    $pdo->exec("CREATE TABLE IF NOT EXISTS devices (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        code        TEXT NOT NULL,
        udid        TEXT NOT NULL,
        device_name TEXT,
        ios_version TEXT,
        app_version TEXT,
        first_seen  TEXT NOT NULL DEFAULT (datetime('now')),
        last_seen   TEXT NOT NULL DEFAULT (datetime('now')),
        UNIQUE(code, udid)
    )");

    // جدول نبضات الحياة — للتتبع الدوري
    $pdo->exec("CREATE TABLE IF NOT EXISTS heartbeats (
        id   INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        udid TEXT NOT NULL,
        ts   TEXT NOT NULL DEFAULT (datetime('now'))
    )");
}

// ============================================================
// دوال مساعدة
// ============================================================

/** إرسال رد JSON وإنهاء الطلب */
function jsonResponse(array $data, int $status = 200): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

/** التحقق من مفتاح API في ترويسة الطلب أو الـ POST */
function requireApiKey(): void
{
    $provided = $_SERVER['HTTP_X_API_KEY']
        ?? $_POST['api_key']
        ?? $_GET['api_key']
        ?? '';
    $expected = GPSQ_API_KEY;

    if ($expected === '' || !hash_equals($expected, $provided)) {
        jsonResponse(['success' => false, 'error' => 'مفتاح API غير صحيح'], 401);
    }
}
