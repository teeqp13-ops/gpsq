<?php
declare(strict_types=1);

/**
 * إعدادات مشتركة لـ GPS Plus Server
 *
 * متغيرات البيئة المطلوبة عند النشر:
 *   GPSQ_API_KEY          — مفتاح API للتحقق من طلبات التفعيل
 *   GPSQ_ADMIN_PASSWORD   — كلمة مرور لوحة الإدارة
 */

$_localCfg = __DIR__ . '/config.local.php';
if (file_exists($_localCfg)) {
    require_once $_localCfg;
}

if (!defined('GPSQ_API_KEY')) {
    define('GPSQ_API_KEY', getenv('GPSQ_API_KEY') ?: '');
}

if (!defined('GPSQ_ADMIN_PASSWORD')) {
    define('GPSQ_ADMIN_PASSWORD', getenv('GPSQ_ADMIN_PASSWORD') ?: '');
}

if (!defined('DB_PATH')) {
    define('DB_PATH', __DIR__ . '/../../../gpsq.db');
}

function getDB(): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $dbDir = dirname(DB_PATH);
    if (!is_dir($dbDir) && !mkdir($dbDir, 0775, true) && !is_dir($dbDir)) {
        throw new RuntimeException('تعذر إنشاء مجلد قاعدة البيانات');
    }

    $pdo = new PDO('sqlite:' . DB_PATH);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    $pdo->exec('PRAGMA foreign_keys = ON');

    initSchema($pdo);
    return $pdo;
}

function initSchema(PDO $pdo): void
{
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

    $pdo->exec("CREATE TABLE IF NOT EXISTS heartbeats (
        id   INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        udid TEXT NOT NULL,
        ts   TEXT NOT NULL DEFAULT (datetime('now'))
    )");

    $pdo->exec('CREATE INDEX IF NOT EXISTS idx_codes_status ON codes (status)');
    $pdo->exec('CREATE INDEX IF NOT EXISTS idx_devices_code ON devices (code)');
    $pdo->exec('CREATE INDEX IF NOT EXISTS idx_heartbeats_code ON heartbeats (code, udid)');
}

function jsonResponse(array $data, int $status = 200): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function requestInput(): array
{
    $contentType = strtolower((string)($_SERVER['CONTENT_TYPE'] ?? ''));
    if (str_contains($contentType, 'application/json')) {
        $decoded = json_decode((string)file_get_contents('php://input'), true);
        return is_array($decoded) ? $decoded : [];
    }

    return $_POST;
}

function requirePost(): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
        jsonResponse(['success' => false, 'error' => 'POST مطلوب'], 405);
    }
}

function requireApiKey(): void
{
    $input = requestInput();
    $authorization = (string)($_SERVER['HTTP_AUTHORIZATION'] ?? '');
    $bearer = str_starts_with($authorization, 'Bearer ')
        ? trim(substr($authorization, 7))
        : '';

    $provided = (string)(
        $_SERVER['HTTP_X_API_KEY']
        ?? $_SERVER['HTTP_X_GPS_API_KEY']
        ?? $input['api_key']
        ?? $_GET['api_key']
        ?? $bearer
        ?? ''
    );

    $expected = (string)GPSQ_API_KEY;
    if ($expected === '') {
        jsonResponse(['success' => false, 'error' => 'مفتاح API غير مضبوط على الخادم'], 500);
    }

    if ($provided === '' || !hash_equals($expected, $provided)) {
        jsonResponse(['success' => false, 'error' => 'مفتاح API غير صحيح'], 401);
    }
}
