<?php
declare(strict_types=1);
$error = null;
$done = false;
$lock = __DIR__ . '/storage/install.lock';
if (is_file($lock)) { http_response_code(403); exit('تم تثبيت النظام مسبقًا.'); }
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        if (!extension_loaded('pdo_sqlite')) throw new RuntimeException('امتداد PDO SQLite غير مفعّل.');
        $adminUser = trim((string)($_POST['admin_user'] ?? 'admin'));
        $adminPass = (string)($_POST['admin_password'] ?? '');
        if ($adminUser === '' || strlen($adminPass) < 8) throw new RuntimeException('أدخل اسم مدير وكلمة مرور من 8 أحرف على الأقل.');
        @mkdir(__DIR__ . '/storage', 0755, true);
        $config = "<?php\nreturn " . var_export([
            'app_name' => 'GPSQ Activation',
            'project_key' => 'gpsq',
            'base_url' => 'https://key.p3nd.fun',
            'database_path' => __DIR__ . '/storage/activation.sqlite',
            'session_ttl' => 2592000,
            'device_limit' => 1,
            'maintenance' => false,
        ], true) . ";\n";
        file_put_contents(__DIR__ . '/config.php', $config, LOCK_EX);
        $pdo = new PDO('sqlite:' . __DIR__ . '/storage/activation.sqlite');
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $pdo->exec('CREATE TABLE IF NOT EXISTS admins (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL, created_at TEXT NOT NULL)');
        $pdo->exec('CREATE TABLE IF NOT EXISTS licenses (id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT UNIQUE NOT NULL, is_active INTEGER NOT NULL DEFAULT 1, device_limit INTEGER NOT NULL DEFAULT 1, expires_at TEXT NULL, created_at TEXT NOT NULL)');
        $pdo->exec('CREATE TABLE IF NOT EXISTS license_devices (id INTEGER PRIMARY KEY AUTOINCREMENT, license_id INTEGER NOT NULL, device_hash TEXT NOT NULL, created_at TEXT NOT NULL, last_seen_at TEXT NOT NULL, UNIQUE(license_id, device_hash))');
        $pdo->exec('CREATE TABLE IF NOT EXISTS activation_sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, license_id INTEGER NOT NULL, device_hash TEXT NOT NULL, token_hash TEXT UNIQUE NOT NULL, expires_at TEXT NOT NULL, created_at TEXT NOT NULL)');
        $stmt = $pdo->prepare('INSERT INTO admins (username,password_hash,created_at) VALUES (:u,:p,:c)');
        $stmt->execute([':u'=>$adminUser, ':p'=>password_hash($adminPass, PASSWORD_DEFAULT), ':c'=>date(DATE_ATOM)]);
        file_put_contents($lock, date(DATE_ATOM), LOCK_EX);
        $done = true;
    } catch (Throwable $e) { $error = $e->getMessage(); }
}
?><!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>تثبيت GPSQ</title><style>body{font-family:Arial;background:#07121c;color:#fff;display:grid;place-items:center;min-height:100vh;margin:0}.card{width:min(92%,480px);background:#102638;padding:24px;border-radius:22px}input,button{width:100%;box-sizing:border-box;padding:13px;margin:7px 0;border-radius:12px;border:0}button{background:#19aaf5;color:#fff;font-weight:700}.ok{color:#6ee7b7}.err{color:#fca5a5}</style><div class="card"><h1>تثبيت GPSQ Activation</h1><?php if($done):?><p class="ok">تم التثبيت بنجاح. احذف أو أعد تسمية install.php.</p><?php else:?><?php if($error):?><p class="err"><?=htmlspecialchars($error)?></p><?php endif;?><form method="post"><input name="admin_user" value="admin" placeholder="اسم المدير" required><input type="password" name="admin_password" placeholder="كلمة المرور" required><button>بدء التثبيت</button></form><?php endif;?></div>