<?php
declare(strict_types=1);

$_localCfg = __DIR__ . '/config.local.php';
if (is_file($_localCfg)) {
    require_once $_localCfg;
}

if (!defined('GPSQ_API_KEY')) {
    define('GPSQ_API_KEY', getenv('GPSQ_API_KEY') ?: '');
}
if (!defined('GPSQ_ADMIN_PASSWORD')) {
    define('GPSQ_ADMIN_PASSWORD', getenv('GPSQ_ADMIN_PASSWORD') ?: '');
}
if (!defined('GPSQ_HMAC_SECRET')) {
    define('GPSQ_HMAC_SECRET', getenv('GPSQ_HMAC_SECRET') ?: GPSQ_API_KEY);
}
if (!defined('DB_PATH')) {
    define('DB_PATH', dirname(__DIR__, 2) . '/data/gpsq.sqlite');
}

function getDB(): PDO
{
    static $pdo;
    if ($pdo instanceof PDO) return $pdo;

    $dir = dirname(DB_PATH);
    if (!is_dir($dir) && !mkdir($dir, 0775, true) && !is_dir($dir)) {
        throw new RuntimeException('تعذر إنشاء مجلد قاعدة البيانات');
    }

    $pdo = new PDO('sqlite:' . DB_PATH);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    $pdo->exec('PRAGMA foreign_keys=ON');
    $pdo->exec('PRAGMA journal_mode=WAL');
    $pdo->exec('PRAGMA busy_timeout=5000');
    initSchema($pdo);
    return $pdo;
}

function ensureColumn(PDO $pdo, string $table, string $column, string $definition): void
{
    $columns = $pdo->query("PRAGMA table_info($table)")->fetchAll();
    foreach ($columns as $item) {
        if (($item['name'] ?? '') === $column) return;
    }
    $pdo->exec("ALTER TABLE $table ADD COLUMN $column $definition");
}

function initSchema(PDO $pdo): void
{
    $pdo->exec("CREATE TABLE IF NOT EXISTS codes (
        code TEXT PRIMARY KEY,
        status TEXT NOT NULL DEFAULT 'unused',
        udid TEXT,
        device_name TEXT,
        ios_version TEXT,
        app_version TEXT,
        duration_days INTEGER NOT NULL DEFAULT 30,
        max_devices INTEGER NOT NULL DEFAULT 1,
        note TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        activated_at TEXT,
        expires_at TEXT
    )");

    ensureColumn($pdo, 'codes', 'duration_days', "INTEGER NOT NULL DEFAULT 30");
    ensureColumn($pdo, 'codes', 'max_devices', "INTEGER NOT NULL DEFAULT 1");
    ensureColumn($pdo, 'codes', 'note', 'TEXT');
    ensureColumn($pdo, 'codes', 'expires_at', 'TEXT');

    $pdo->exec("CREATE TABLE IF NOT EXISTS devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        udid TEXT NOT NULL,
        device_name TEXT,
        ios_version TEXT,
        app_version TEXT,
        first_seen TEXT NOT NULL DEFAULT (datetime('now')),
        last_seen TEXT NOT NULL DEFAULT (datetime('now')),
        UNIQUE(code, udid),
        FOREIGN KEY(code) REFERENCES codes(code) ON DELETE CASCADE
    )");

    $pdo->exec("CREATE TABLE IF NOT EXISTS activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT,
        udid TEXT,
        action TEXT NOT NULL,
        result TEXT NOT NULL,
        message TEXT,
        ip TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )");

    $pdo->exec("CREATE TABLE IF NOT EXISTS settings (
        name TEXT PRIMARY KEY,
        value TEXT,
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )");

    $pdo->exec("INSERT OR IGNORE INTO settings(name,value) VALUES
        ('maintenance','0'),
        ('force_update','0'),
        ('minimum_version','1.0'),
        ('server_message','')");

    $pdo->exec('CREATE INDEX IF NOT EXISTS idx_codes_status ON codes(status)');
    $pdo->exec('CREATE INDEX IF NOT EXISTS idx_codes_expiry ON codes(expires_at)');
    $pdo->exec('CREATE INDEX IF NOT EXISTS idx_devices_code ON devices(code)');
    $pdo->exec('CREATE INDEX IF NOT EXISTS idx_logs_code ON activity_logs(code, created_at)');
}

function jsonResponse(array $data, int $status = 200): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function requestInput(): array
{
    static $input;
    if (is_array($input)) return $input;
    $contentType = strtolower((string)($_SERVER['CONTENT_TYPE'] ?? ''));
    if (str_contains($contentType, 'application/json')) {
        $decoded = json_decode((string)file_get_contents('php://input'), true);
        return $input = is_array($decoded) ? $decoded : [];
    }
    return $input = $_POST;
}

function requirePost(): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
        jsonResponse(['success' => false, 'status' => 'method_not_allowed', 'message' => 'POST مطلوب'], 405);
    }
}

function requireApiKey(): void
{
    $authorization = (string)($_SERVER['HTTP_AUTHORIZATION'] ?? '');
    $bearer = str_starts_with($authorization, 'Bearer ') ? trim(substr($authorization, 7)) : '';
    $input = requestInput();
    $provided = (string)($_SERVER['HTTP_X_API_KEY'] ?? $_SERVER['HTTP_X_GPS_API_KEY'] ?? $input['api_key'] ?? $_GET['api_key'] ?? $bearer);
    $expected = (string)GPSQ_API_KEY;
    if ($expected === '') jsonResponse(['success'=>false,'message'=>'مفتاح API غير مضبوط'], 500);
    if ($provided === '' || !hash_equals($expected, $provided)) jsonResponse(['success'=>false,'message'=>'مفتاح API غير صحيح'], 401);
}

function setting(string $name, string $default = ''): string
{
    $stmt = getDB()->prepare('SELECT value FROM settings WHERE name=?');
    $stmt->execute([$name]);
    $value = $stmt->fetchColumn();
    return $value === false ? $default : (string)$value;
}

function clientIp(): string
{
    return substr((string)($_SERVER['HTTP_CF_CONNECTING_IP'] ?? $_SERVER['REMOTE_ADDR'] ?? ''), 0, 64);
}

function logActivity(?string $code, ?string $udid, string $action, string $result, string $message = ''): void
{
    getDB()->prepare('INSERT INTO activity_logs(code,udid,action,result,message,ip) VALUES(?,?,?,?,?,?)')
        ->execute([$code, $udid, $action, $result, $message, clientIp()]);
}
