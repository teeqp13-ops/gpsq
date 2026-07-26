<?php
declare(strict_types=1);

error_reporting(E_ALL);
ini_set('display_errors', '1');

session_start();
$error = null;
$done = false;
$installed = false;
$firstCode = null;
$storageDir = __DIR__ . '/storage';
$lockFile = $storageDir . '/install.lock';
$configFile = __DIR__ . '/config.php';
$databaseFile = $storageDir . '/activation.sqlite';

if (is_file($lockFile) && is_file($configFile)) {
    $installed = true;
}

if (empty($_SESSION['gpsq_install_csrf'])) {
    $_SESSION['gpsq_install_csrf'] = bin2hex(random_bytes(24));
}

$checks = [
    'PHP 7.4 أو أحدث' => version_compare(PHP_VERSION, '7.4.0', '>='),
    'امتداد PDO' => extension_loaded('pdo'),
    'امتداد PDO SQLite' => extension_loaded('pdo_sqlite'),
    'دالة password_hash' => function_exists('password_hash'),
    'دالة random_bytes' => function_exists('random_bytes'),
];

if ($_SERVER['REQUEST_METHOD'] === 'POST' && !$installed) {
    try {
        $csrf = isset($_POST['csrf']) ? (string) $_POST['csrf'] : '';
        if (!hash_equals((string) $_SESSION['gpsq_install_csrf'], $csrf)) {
            throw new RuntimeException('انتهت جلسة التثبيت. حدّث الصفحة وحاول مرة أخرى.');
        }
        foreach ($checks as $label => $passed) {
            if (!$passed) throw new RuntimeException('فشل فحص الخادم: ' . $label);
        }

        $adminUser = trim(isset($_POST['admin_user']) ? (string) $_POST['admin_user'] : 'admin');
        $adminPass = isset($_POST['admin_password']) ? (string) $_POST['admin_password'] : '';
        if ($adminUser === '' || !preg_match('/^[A-Za-z0-9_.-]{3,40}$/', $adminUser)) {
            throw new RuntimeException('اسم المدير يجب أن يكون من 3 إلى 40 حرفًا إنجليزيًا أو رقمًا.');
        }
        if (strlen($adminPass) < 8) {
            throw new RuntimeException('كلمة المرور يجب ألا تقل عن 8 أحرف.');
        }

        if (!is_dir($storageDir) && !mkdir($storageDir, 0775, true) && !is_dir($storageDir)) {
            throw new RuntimeException('تعذر إنشاء مجلد storage.');
        }
        if (!is_writable($storageDir)) {
            throw new RuntimeException('مجلد storage غير قابل للكتابة. غيّر صلاحيته إلى 775.');
        }
        if (!is_writable(__DIR__)) {
            throw new RuntimeException('مجلد activation غير قابل للكتابة لإنشاء config.php.');
        }

        $settings = [
            'app_name' => 'GPSQ Activation',
            'project_key' => 'gpsq',
            'base_url' => 'https://key.p3nd.fun',
            'database_path' => $databaseFile,
            'session_ttl' => 2592000,
            'device_limit' => 1,
            'maintenance' => false,
            'minimum_app_version' => '1.0.0',
        ];
        $configContent = "<?php\nreturn " . var_export($settings, true) . ";\n";
        if (file_put_contents($configFile, $configContent, LOCK_EX) === false) {
            throw new RuntimeException('تعذر إنشاء config.php.');
        }
        @chmod($configFile, 0640);

        $pdo = new PDO('sqlite:' . $databaseFile);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
        $pdo->exec('PRAGMA foreign_keys = ON');
        $pdo->beginTransaction();

        $pdo->exec('CREATE TABLE IF NOT EXISTS admins (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NULL
        )');
        $pdo->exec('CREATE TABLE IF NOT EXISTS licenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT UNIQUE NOT NULL,
            customer_name TEXT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            device_limit INTEGER NOT NULL DEFAULT 1,
            expires_at TEXT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NULL
        )');
        $pdo->exec('CREATE TABLE IF NOT EXISTS license_devices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            license_id INTEGER NOT NULL,
            device_hash TEXT NOT NULL,
            created_at TEXT NOT NULL,
            last_seen_at TEXT NOT NULL,
            UNIQUE(license_id, device_hash),
            FOREIGN KEY(license_id) REFERENCES licenses(id) ON DELETE CASCADE
        )');
        $pdo->exec('CREATE TABLE IF NOT EXISTS activation_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            license_id INTEGER NOT NULL,
            device_hash TEXT NOT NULL,
            token_hash TEXT UNIQUE NOT NULL,
            expires_at TEXT NOT NULL,
            created_at TEXT NOT NULL,
            last_seen_at TEXT NULL,
            FOREIGN KEY(license_id) REFERENCES licenses(id) ON DELETE CASCADE
        )');
        $pdo->exec('CREATE TABLE IF NOT EXISTS activation_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            license_id INTEGER NULL,
            event TEXT NOT NULL,
            device_hash TEXT NULL,
            ip_address TEXT NULL,
            details TEXT NULL,
            created_at TEXT NOT NULL
        )');
        $pdo->exec('CREATE INDEX IF NOT EXISTS idx_sessions_token ON activation_sessions(token_hash)');
        $pdo->exec('CREATE INDEX IF NOT EXISTS idx_devices_license ON license_devices(license_id)');

        $admin = $pdo->prepare('INSERT INTO admins (username, password_hash, created_at) VALUES (:username, :password, :created_at)');
        $admin->execute([
            ':username' => $adminUser,
            ':password' => password_hash($adminPass, PASSWORD_DEFAULT),
            ':created_at' => date(DATE_ATOM),
        ]);

        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        $suffix = '';
        for ($i = 0; $i < 4; $i++) $suffix .= $alphabet[random_int(0, strlen($alphabet) - 1)];
        $firstCode = 'GPSQ' . $suffix;
        $license = $pdo->prepare('INSERT INTO licenses (code, customer_name, is_active, device_limit, expires_at, created_at) VALUES (:code, :name, 1, 1, :expires_at, :created_at)');
        $license->execute([
            ':code' => $firstCode,
            ':name' => 'كود تجربة التثبيت',
            ':expires_at' => date(DATE_ATOM, strtotime('+30 days')),
            ':created_at' => date(DATE_ATOM),
        ]);

        $pdo->commit();
        @chmod($databaseFile, 0660);
        if (file_put_contents($lockFile, date(DATE_ATOM), LOCK_EX) === false) {
            throw new RuntimeException('تم إنشاء القاعدة لكن تعذر إنشاء ملف قفل التثبيت.');
        }
        $done = true;
        $installed = true;
        unset($_SESSION['gpsq_install_csrf']);
    } catch (Throwable $exception) {
        if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) $pdo->rollBack();
        $error = $exception->getMessage();
    }
}
?><!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>تثبيت GPSQ Activation</title>
<style>
:root{--bg:#070b18;--card:#0e142b;--gold:#c9a227;--gold2:#e8c453;--text:#fff;--muted:#8a93a8;--ok:#3fd68a;--bad:#ff6b78}*{box-sizing:border-box}body{margin:0;min-height:100vh;display:grid;place-items:center;padding:20px;background:radial-gradient(circle at 80% 10%,rgba(201,162,39,.12),transparent 35%),var(--bg);color:var(--text);font-family:Tahoma,Arial,sans-serif}.card{width:min(100%,560px);background:var(--card);border:1px solid rgba(255,255,255,.08);border-radius:24px;padding:24px;box-shadow:0 30px 80px rgba(0,0,0,.4)}h1{margin:0 0 8px;font-size:25px}.sub{color:var(--muted);line-height:1.8;margin-bottom:18px}.checks{display:grid;gap:8px;margin:16px 0}.check{display:flex;justify-content:space-between;padding:11px 13px;border-radius:12px;background:rgba(255,255,255,.04);font-size:13px}.yes{color:var(--ok)}.no{color:var(--bad)}label{display:block;margin:13px 0 7px;font-weight:700;font-size:13px}input{width:100%;padding:14px;border:1px solid rgba(255,255,255,.1);border-radius:13px;background:#070b18;color:#fff;outline:none}input:focus{border-color:var(--gold)}button{width:100%;padding:14px;margin-top:16px;border:0;border-radius:13px;background:linear-gradient(135deg,var(--gold),var(--gold2));color:#070b18;font-weight:900;font-size:15px;cursor:pointer}.message{padding:14px;border-radius:13px;margin:14px 0;line-height:1.7}.error{background:rgba(255,107,120,.1);border:1px solid rgba(255,107,120,.3);color:#ffd0d5}.success{background:rgba(63,214,138,.1);border:1px solid rgba(63,214,138,.3);color:#bdffdc}.code{direction:ltr;text-align:center;font-family:monospace;font-size:24px;letter-spacing:3px;padding:13px;border-radius:12px;background:#070b18;color:var(--gold2);margin:12px 0}.links a{color:var(--gold2);text-decoration:none;display:block;margin-top:10px}</style>
</head>
<body><main class="card">
<h1>GPSQ Activation</h1>
<div class="sub">مُثبّت نظام التفعيل المرتبط بـ key.p3nd.fun</div>
<div class="checks">
<?php foreach ($checks as $label => $passed): ?>
<div class="check"><span><?= htmlspecialchars($label, ENT_QUOTES, 'UTF-8') ?></span><strong class="<?= $passed ? 'yes' : 'no' ?>"><?= $passed ? 'جاهز' : 'غير متوفر' ?></strong></div>
<?php endforeach; ?>
</div>
<?php if ($error): ?><div class="message error"><?= htmlspecialchars($error, ENT_QUOTES, 'UTF-8') ?></div><?php endif; ?>
<?php if ($done): ?>
<div class="message success">تم التثبيت بنجاح وإنشاء أول كود تجريبي لمدة 30 يومًا.</div>
<div class="code"><?= htmlspecialchars((string) $firstCode, ENT_QUOTES, 'UTF-8') ?></div>
<div class="links"><a href="api/status.php">اختبار حالة API</a><a href="admin/">فتح لوحة الإدارة</a></div>
<?php elseif ($installed): ?>
<div class="message success">النظام مثبت مسبقًا. احذف ملف <b>storage/install.lock</b> فقط عند الحاجة لإعادة التثبيت.</div>
<div class="links"><a href="api/status.php">اختبار حالة API</a><a href="admin/">فتح لوحة الإدارة</a></div>
<?php else: ?>
<form method="post" autocomplete="off">
<input type="hidden" name="csrf" value="<?= htmlspecialchars((string) $_SESSION['gpsq_install_csrf'], ENT_QUOTES, 'UTF-8') ?>">
<label for="admin_user">اسم المدير</label><input id="admin_user" name="admin_user" value="admin" required maxlength="40">
<label for="admin_password">كلمة المرور</label><input id="admin_password" type="password" name="admin_password" required minlength="8" placeholder="8 أحرف على الأقل">
<button type="submit">بدء التثبيت</button>
</form>
<?php endif; ?>
</main></body></html>
