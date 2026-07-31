<?php
declare(strict_types=1);

require_once __DIR__ . '/api/config.php';

header('X-Robots-Tag: noindex, nofollow, noarchive, nosnippet', true);
header('X-Frame-Options: DENY');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: no-referrer');
header("Permissions-Policy: camera=(), microphone=(), geolocation=()");
header("Content-Security-Policy: default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; script-src 'self' 'unsafe-inline'; frame-ancestors 'none'; form-action 'self'; base-uri 'self'");
header('Cache-Control: no-store, private, max-age=0');

session_name('wolfgps_admin');
session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/',
    'secure' => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off',
    'httponly' => true,
    'samesite' => 'Strict',
]);
session_start();

if (empty($_SESSION['csrf'])) {
    $_SESSION['csrf'] = bin2hex(random_bytes(32));
}
$csrf = (string)$_SESSION['csrf'];

function e(?string $value): string
{
    return htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function clip(?string $value, int $length): string
{
    $text = (string)$value;
    return function_exists('mb_substr') ? mb_substr($text, 0, $length, 'UTF-8') : substr($text, 0, $length);
}

function csrf(): void
{
    $provided = (string)($_POST['csrf'] ?? '');
    if ($provided === '' || !hash_equals((string)($_SESSION['csrf'] ?? ''), $provided)) {
        http_response_code(403);
        exit('طلب غير صالح');
    }
}

function redirectPanel(string $tab = 'dashboard', string $message = ''): never
{
    if ($message !== '') $_SESSION['flash'] = $message;
    header('Location: index.php?tab=' . rawurlencode($tab));
    exit;
}

function randomLicenseCode(int $length): string
{
    $length = max(8, min(20, $length));
    $code = '';
    for ($i = 0; $i < $length; $i++) $code .= (string)random_int(0, 9);
    return $code;
}

function statusLabel(string $status): string
{
    return [
        'unused' => 'غير مستخدم',
        'linked' => 'مرتبط',
        'expired' => 'منتهي',
        'closed' => 'موقوف',
    ][$status] ?? $status;
}

$loginError = '';
$now = time();
$lockedUntil = (int)($_SESSION['login_locked_until'] ?? 0);

if (isset($_POST['login'])) {
    csrf();
    if ($lockedUntil > $now) {
        $loginError = 'محاولات كثيرة. انتظر عدة دقائق.';
    } else {
        $password = (string)($_POST['password'] ?? '');
        $expected = (string)GPSQ_ADMIN_PASSWORD;
        if ($expected !== '' && hash_equals($expected, $password)) {
            session_regenerate_id(true);
            $_SESSION['auth'] = true;
            $_SESSION['login_attempts'] = 0;
            $_SESSION['csrf'] = bin2hex(random_bytes(32));
            redirectPanel();
        }
        $attempts = (int)($_SESSION['login_attempts'] ?? 0) + 1;
        $_SESSION['login_attempts'] = $attempts;
        if ($attempts >= 5) {
            $_SESSION['login_locked_until'] = $now + 600;
            $_SESSION['login_attempts'] = 0;
        }
        usleep(350000);
        $loginError = 'كلمة المرور غير صحيحة';
    }
}

$isAuth = !empty($_SESSION['auth']);
if (isset($_POST['logout']) && $isAuth) {
    csrf();
    $_SESSION = [];
    session_destroy();
    header('Location: index.php');
    exit;
}

if ($isAuth) {
    $db = getDB();

    if (isset($_POST['create_codes'])) {
        csrf();
        $manual = strtoupper(trim((string)($_POST['manual_code'] ?? '')));
        $quantity = max(1, min(100, (int)($_POST['quantity'] ?? 1)));
        $codeLength = max(8, min(20, (int)($_POST['code_length'] ?? 8)));
        $duration = max(1, min(3650, (int)($_POST['duration_days'] ?? 30)));
        $maxDevices = max(1, min(10, (int)($_POST['max_devices'] ?? 1)));
        $note = clip(trim((string)($_POST['note'] ?? '')), 160);
        if ($manual !== '' && !preg_match('/^[0-9]{8,20}$/', $manual)) {
            redirectPanel('codes', 'الكود اليدوي يجب أن يحتوي على 8 إلى 20 رقمًا فقط.');
        }
        $created = [];
        $stmt = $db->prepare('INSERT OR IGNORE INTO codes(code,duration_days,max_devices,note) VALUES(?,?,?,?)');
        $target = $manual !== '' ? 1 : $quantity;
        for ($i = 0; $i < $target; $i++) {
            for ($retry = 0; $retry < 20; $retry++) {
                $code = $manual !== '' ? $manual : randomLicenseCode($codeLength);
                $stmt->execute([$code, $duration, $maxDevices, $note]);
                if ($stmt->rowCount() > 0) {
                    $created[] = $code;
                    break;
                }
                if ($manual !== '') break;
            }
        }
        logActivity($created[0] ?? null, null, 'admin_create', $created ? 'success' : 'failed', 'count=' . count($created));
        redirectPanel('codes', $created ? 'تم إنشاء ' . count($created) . ' كود.' : 'تعذر إنشاء الكود أو أنه موجود.');
    }

    if (isset($_POST['change_status'])) {
        csrf();
        $code = strtoupper(trim((string)($_POST['code'] ?? '')));
        $status = (string)($_POST['status'] ?? '');
        if (preg_match('/^[0-9]{8,20}$/', $code) && in_array($status, ['unused','linked','expired','closed'], true)) {
            $db->prepare('UPDATE codes SET status=? WHERE code=?')->execute([$status, $code]);
            logActivity($code, null, 'admin_status', 'success', $status);
        }
        redirectPanel('codes', 'تم تحديث حالة الكود.');
    }

    if (isset($_POST['reset_code'])) {
        csrf();
        $code = strtoupper(trim((string)($_POST['code'] ?? '')));
        $db->beginTransaction();
        try {
            $db->prepare('DELETE FROM devices WHERE code=?')->execute([$code]);
            $db->prepare("UPDATE codes SET status='unused',udid=NULL,device_name=NULL,ios_version=NULL,app_version=NULL,activated_at=NULL,expires_at=NULL WHERE code=?")->execute([$code]);
            $db->commit();
            logActivity($code, null, 'admin_reset', 'success', 'device_detached');
            redirectPanel('codes', 'تم فصل الجهاز وإعادة تعيين الكود.');
        } catch (Throwable $exception) {
            if ($db->inTransaction()) $db->rollBack();
            redirectPanel('codes', 'تعذر إعادة تعيين الكود.');
        }
    }

    if (isset($_POST['delete_code'])) {
        csrf();
        $code = strtoupper(trim((string)($_POST['code'] ?? '')));
        $db->prepare('DELETE FROM codes WHERE code=?')->execute([$code]);
        logActivity($code, null, 'admin_delete', 'success');
        redirectPanel('codes', 'تم حذف الكود.');
    }

    if (isset($_POST['disconnect_device'])) {
        csrf();
        $deviceId = (int)($_POST['device_id'] ?? 0);
        $stmt = $db->prepare('SELECT code,udid FROM devices WHERE id=?');
        $stmt->execute([$deviceId]);
        $device = $stmt->fetch();
        if ($device) {
            $db->prepare('DELETE FROM devices WHERE id=?')->execute([$deviceId]);
            $count = $db->prepare('SELECT COUNT(*) FROM devices WHERE code=?');
            $count->execute([$device['code']]);
            if ((int)$count->fetchColumn() === 0) {
                $db->prepare("UPDATE codes SET status='unused',udid=NULL,device_name=NULL,ios_version=NULL,app_version=NULL,activated_at=NULL,expires_at=NULL WHERE code=?")->execute([$device['code']]);
            }
            logActivity((string)$device['code'], (string)$device['udid'], 'admin_disconnect', 'success');
        }
        redirectPanel('devices', 'تم فصل الجهاز.');
    }

    if (isset($_POST['save_settings'])) {
        csrf();
        $settings = [
            'maintenance' => isset($_POST['maintenance']) ? '1' : '0',
            'force_update' => isset($_POST['force_update']) ? '1' : '0',
            'minimum_version' => preg_replace('/[^0-9.]/', '', (string)($_POST['minimum_version'] ?? '17.0.0')) ?: '17.0.0',
            'server_message' => clip(trim((string)($_POST['server_message'] ?? '')), 240),
        ];
        $stmt = $db->prepare("INSERT INTO settings(name,value,updated_at) VALUES(?,?,datetime('now')) ON CONFLICT(name) DO UPDATE SET value=excluded.value,updated_at=datetime('now')");
        foreach ($settings as $name => $value) $stmt->execute([$name, $value]);
        logActivity(null, null, 'admin_settings', 'success');
        redirectPanel('settings', 'تم حفظ الإعدادات.');
    }

    if (isset($_POST['clear_logs'])) {
        csrf();
        $db->exec('DELETE FROM activity_logs');
        redirectPanel('logs', 'تم مسح السجل.');
    }

    if (isset($_POST['download_backup'])) {
        csrf();
        if (!is_file(DB_PATH)) redirectPanel('settings', 'لا توجد قاعدة بيانات بعد.');
        header('Content-Type: application/octet-stream');
        header('Content-Disposition: attachment; filename="wolfgps-v17-' . gmdate('Ymd-His') . '.sqlite"');
        header('Content-Length: ' . filesize(DB_PATH));
        readfile(DB_PATH);
        exit;
    }
}

$allowedTabs = ['dashboard','codes','devices','logs','settings','api'];
$tab = (string)($_GET['tab'] ?? 'dashboard');
if (!in_array($tab, $allowedTabs, true)) $tab = 'dashboard';
$flash = (string)($_SESSION['flash'] ?? '');
unset($_SESSION['flash']);

$stats = ['total'=>0,'unused'=>0,'linked'=>0,'expired'=>0,'closed'=>0,'devices'=>0,'logs'=>0];
$codes = $devices = $logs = [];
$settings = ['maintenance'=>'0','force_update'=>'0','minimum_version'=>'17.0.0','server_message'=>''];
if ($isAuth) {
    $db = getDB();
    foreach ($db->query('SELECT status,COUNT(*) total FROM codes GROUP BY status') as $row) {
        if (array_key_exists($row['status'], $stats)) $stats[$row['status']] = (int)$row['total'];
    }
    $stats['total'] = $stats['unused'] + $stats['linked'] + $stats['expired'] + $stats['closed'];
    $stats['devices'] = (int)$db->query('SELECT COUNT(*) FROM devices')->fetchColumn();
    $stats['logs'] = (int)$db->query('SELECT COUNT(*) FROM activity_logs')->fetchColumn();
    $codes = $db->query('SELECT * FROM codes ORDER BY created_at DESC LIMIT 500')->fetchAll();
    $devices = $db->query('SELECT * FROM devices ORDER BY last_seen DESC LIMIT 500')->fetchAll();
    $logs = $db->query('SELECT * FROM activity_logs ORDER BY id DESC LIMIT 300')->fetchAll();
    foreach ($db->query('SELECT name,value FROM settings')->fetchAll() as $row) $settings[$row['name']] = (string)$row['value'];
}
?>
<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="robots" content="noindex,nofollow,noarchive,nosnippet">
<meta name="googlebot" content="noindex,nofollow,noarchive,nosnippet">
<title>Wolf GPS V17 — لوحة التحكم</title>
<style>
:root{--primary:#19aaf5;--accent:#7a5cff;--bg:#05080d;--card:#0b1620;--card2:#102638;--border:rgba(25,170,245,.32);--text:#f7fbff;--muted:#9ba8b5;--ok:#19d391;--warn:#f7ba45;--bad:#ff5d6c;--radius:22px}
*{box-sizing:border-box}html{background:var(--bg)}body{margin:0;min-height:100vh;color:var(--text);font-family:Tahoma,Arial,sans-serif;background:radial-gradient(circle at 85% 10%,rgba(25,170,245,.16),transparent 28%),radial-gradient(circle at 10% 70%,rgba(122,92,255,.13),transparent 31%),linear-gradient(180deg,#04070c,#07121c,#04070c)}
button,input,select,textarea{font:inherit}.login{min-height:100vh;display:grid;place-items:center;padding:22px}.login-card{width:min(100%,410px);padding:30px;background:rgba(11,22,32,.9);border:1px solid var(--border);border-radius:28px;box-shadow:0 25px 80px #0008}.logo{width:66px;height:66px;margin:auto;border-radius:22px;display:grid;place-items:center;font-size:30px;background:linear-gradient(135deg,var(--primary),var(--accent));box-shadow:0 12px 36px #19aaf544}h1,h2,h3,p{margin-top:0}.center{text-align:center}.muted{color:var(--muted)}.shell{max-width:1450px;margin:auto;padding:16px}.top{position:sticky;top:0;z-index:20;display:flex;justify-content:space-between;align-items:center;gap:12px;padding:13px 16px;margin-bottom:14px;background:rgba(5,8,13,.86);backdrop-filter:blur(18px);border:1px solid var(--border);border-radius:20px}.brand{display:flex;align-items:center;gap:11px}.brand-mark{width:42px;height:42px;border-radius:14px;display:grid;place-items:center;background:linear-gradient(135deg,var(--primary),var(--accent))}.brand small{display:block;color:var(--muted)}.nav{display:flex;gap:8px;overflow:auto;padding:4px 2px 14px;scrollbar-width:none}.nav a{white-space:nowrap;color:var(--muted);text-decoration:none;padding:10px 15px;border:1px solid transparent;border-radius:14px}.nav a.active,.nav a:hover{color:#fff;background:var(--card2);border-color:var(--border)}.grid{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:12px}.stat,.panel{background:linear-gradient(145deg,rgba(16,38,56,.9),rgba(11,22,32,.92));border:1px solid var(--border);border-radius:var(--radius);box-shadow:0 18px 48px #0004}.stat{padding:18px}.stat b{display:block;font-size:28px;margin-bottom:4px}.panel{padding:18px;margin-top:14px}.panel-head{display:flex;justify-content:space-between;align-items:center;gap:10px;margin-bottom:15px}.form-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:10px}.field{display:flex;flex-direction:column;gap:7px}.field label{font-size:12px;color:var(--muted)}input,select,textarea{width:100%;color:#fff;background:#07111a;border:1px solid var(--border);border-radius:13px;padding:11px 12px;outline:none}input:focus,select:focus,textarea:focus{border-color:var(--primary);box-shadow:0 0 0 3px #19aaf51c}.btn{display:inline-flex;justify-content:center;align-items:center;gap:6px;border:0;border-radius:13px;padding:10px 14px;color:#fff;background:var(--card2);cursor:pointer;text-decoration:none}.btn-primary{background:linear-gradient(135deg,var(--primary),var(--accent))}.btn-danger{background:#8f2530}.btn-warn{background:#6f5120}.btn-sm{padding:7px 10px;font-size:12px}.table-wrap{overflow:auto;border:1px solid var(--border);border-radius:16px}table{width:100%;border-collapse:collapse;min-width:820px}th,td{text-align:right;padding:11px 12px;border-bottom:1px solid #ffffff0d;white-space:nowrap}th{color:var(--muted);font-size:12px;background:#07111a}td{font-size:13px}.code{font-family:ui-monospace,monospace;letter-spacing:1px}.badge{padding:5px 9px;border-radius:999px;font-size:11px}.unused{background:#168cc326;color:#63cfff}.linked,.success{background:#19d39120;color:#52edb3}.expired,.warning{background:#f7ba4520;color:#ffd378}.closed,.failed{background:#ff5d6c20;color:#ff8792}.actions{display:flex;gap:6px;align-items:center}.actions form{margin:0}.flash{padding:12px 15px;border:1px solid #19d39155;background:#19d39116;border-radius:15px;margin-bottom:13px}.api-card{padding:15px;border-radius:16px;background:#07111a;border:1px solid var(--border);margin-bottom:10px}.method{display:inline-block;min-width:48px;color:var(--ok);font-family:monospace}.switch-row{display:flex;justify-content:space-between;align-items:center;padding:13px;background:#07111a;border:1px solid var(--border);border-radius:15px}.empty{text-align:center;color:var(--muted);padding:26px}.server-ok{color:var(--ok)}.server-bad{color:var(--bad)}
@media(max-width:900px){.grid{grid-template-columns:repeat(3,1fr)}.form-grid{grid-template-columns:repeat(2,1fr)}}
@media(max-width:600px){.shell{padding:10px}.top{border-radius:16px}.brand h3{font-size:15px}.grid{grid-template-columns:repeat(2,1fr)}.stat{padding:14px}.stat b{font-size:23px}.panel{padding:13px;border-radius:18px}.form-grid{grid-template-columns:1fr}.panel-head{align-items:flex-start;flex-direction:column}.hide-mobile{display:none}}
</style>
</head>
<body>
<?php if (!$isAuth): ?>
<div class="login">
  <form method="post" class="login-card">
    <input type="hidden" name="csrf" value="<?= e($csrf) ?>">
    <div class="logo">🐺</div>
    <h2 class="center" style="margin-top:18px">Wolf GPS V17</h2>
    <p class="center muted">لوحة التحكم الآمنة</p>
    <?php if ($loginError): ?><div class="flash" style="border-color:#ff5d6c55;background:#ff5d6c16"><?= e($loginError) ?></div><?php endif; ?>
    <div class="field"><label>كلمة المرور</label><input type="password" name="password" autocomplete="current-password" required autofocus></div>
    <button class="btn btn-primary" name="login" style="width:100%;margin-top:14px">دخول</button>
  </form>
</div>
<?php else: ?>
<div class="shell">
<header class="top">
  <div class="brand"><div class="brand-mark">🐺</div><div><h3 style="margin:0">Wolf GPS V17</h3><small>لوحة التراخيص</small></div></div>
  <form method="post"><input type="hidden" name="csrf" value="<?= e($csrf) ?>"><button class="btn btn-sm" name="logout">خروج</button></form>
</header>
<nav class="nav">
<?php foreach (['dashboard'=>'الرئيسية','codes'=>'الأكواد','devices'=>'الأجهزة','logs'=>'السجل','settings'=>'الإعدادات','api'=>'API'] as $key=>$label): ?>
<a href="?tab=<?= e($key) ?>" class="<?= $tab===$key?'active':'' ?>"><?= e($label) ?></a>
<?php endforeach; ?>
</nav>
<?php if ($flash): ?><div class="flash"><?= e($flash) ?></div><?php endif; ?>

<?php if ($tab==='dashboard'): ?>
<div class="grid">
  <div class="stat"><b><?= $stats['total'] ?></b><span class="muted">إجمالي الأكواد</span></div>
  <div class="stat"><b style="color:var(--primary)"><?= $stats['unused'] ?></b><span class="muted">غير مستخدم</span></div>
  <div class="stat"><b style="color:var(--ok)"><?= $stats['linked'] ?></b><span class="muted">نشط</span></div>
  <div class="stat"><b style="color:var(--warn)"><?= $stats['expired'] ?></b><span class="muted">منتهي</span></div>
  <div class="stat"><b><?= $stats['devices'] ?></b><span class="muted">الأجهزة</span></div>
  <div class="stat"><b><?= $stats['logs'] ?></b><span class="muted">أحداث السجل</span></div>
</div>
<section class="panel">
  <div class="panel-head"><div><h3>حالة النظام</h3><p class="muted">ربط Wolf GPS V17</p></div><span class="<?= GPSQ_API_KEY!==''&&GPSQ_HMAC_SECRET!==''?'server-ok':'server-bad' ?>">● <?= GPSQ_API_KEY!==''&&GPSQ_HMAC_SECRET!==''?'متصل':'الإعدادات ناقصة' ?></span></div>
  <div class="form-grid">
    <div class="api-card"><span class="muted">الإصدار</span><h3>17.0.0</h3></div>
    <div class="api-card"><span class="muted">قاعدة البيانات</span><h3>SQLite</h3></div>
    <div class="api-card"><span class="muted">الصيانة</span><h3><?= $settings['maintenance']==='1'?'مفعلة':'متوقفة' ?></h3></div>
    <div class="api-card"><span class="muted">التحديث الإجباري</span><h3><?= $settings['force_update']==='1'?'مفعل':'متوقف' ?></h3></div>
    <div class="api-card"><span class="muted">أقل إصدار</span><h3><?= e($settings['minimum_version']) ?></h3></div>
  </div>
</section>

<?php elseif ($tab==='codes'): ?>
<section class="panel" style="margin-top:0">
  <div class="panel-head"><div><h3>إنشاء أكواد V17</h3><p class="muted">الصيغة الموحدة: من 8 إلى 20 رقمًا</p></div></div>
  <form method="post" class="form-grid">
    <input type="hidden" name="csrf" value="<?= e($csrf) ?>">
    <div class="field"><label>كود يدوي (اختياري)</label><input name="manual_code" inputmode="numeric" minlength="8" maxlength="20" pattern="[0-9]{8,20}" placeholder="12345678"></div>
    <div class="field"><label>طول الكود</label><input type="number" name="code_length" min="8" max="20" value="8"></div>
    <div class="field"><label>العدد</label><input type="number" name="quantity" min="1" max="100" value="1"></div>
    <div class="field"><label>المدة بالأيام</label><input type="number" name="duration_days" min="1" max="3650" value="30"></div>
    <div class="field"><label>عدد الأجهزة</label><input type="number" name="max_devices" min="1" max="10" value="1"></div>
    <div class="field"><label>ملاحظة</label><input name="note" maxlength="160"></div>
    <button class="btn btn-primary" name="create_codes">إنشاء الأكواد</button>
  </form>
</section>
<section class="panel">
  <div class="panel-head"><h3>الأكواد</h3><span class="muted"><?= count($codes) ?> نتيجة</span></div>
  <div class="table-wrap"><table><thead><tr><th>الكود</th><th>الحالة</th><th>المدة</th><th>الأجهزة</th><th>التفعيل</th><th>الانتهاء</th><th>الإجراءات</th></tr></thead><tbody>
  <?php foreach ($codes as $row): ?><tr>
    <td class="code"><?= e($row['code']) ?></td><td><span class="badge <?= e($row['status']) ?>"><?= e(statusLabel($row['status'])) ?></span></td>
    <td><?= (int)$row['duration_days'] ?> يوم</td><td><?= (int)$row['max_devices'] ?></td><td><?= e($row['activated_at'] ?: '—') ?></td><td><?= e($row['expires_at'] ?: '—') ?></td>
    <td><div class="actions">
      <form method="post"><input type="hidden" name="csrf" value="<?= e($csrf) ?>"><input type="hidden" name="code" value="<?= e($row['code']) ?>"><select name="status"><option value="unused" <?= $row['status']==='unused'?'selected':'' ?>>غير مستخدم</option><option value="linked" <?= $row['status']==='linked'?'selected':'' ?>>مرتبط</option><option value="expired" <?= $row['status']==='expired'?'selected':'' ?>>منتهي</option><option value="closed" <?= $row['status']==='closed'?'selected':'' ?>>موقوف</option></select><button class="btn btn-sm" name="change_status">حفظ</button></form>
      <form method="post" onsubmit="return confirm('فصل الجهاز وإعادة تعيين الكود؟')"><input type="hidden" name="csrf" value="<?= e($csrf) ?>"><input type="hidden" name="code" value="<?= e($row['code']) ?>"><button class="btn btn-warn btn-sm" name="reset_code">إعادة تعيين</button></form>
      <form method="post" onsubmit="return confirm('حذف الكود نهائيًا؟')"><input type="hidden" name="csrf" value="<?= e($csrf) ?>"><input type="hidden" name="code" value="<?= e($row['code']) ?>"><button class="btn btn-danger btn-sm" name="delete_code">حذف</button></form>
    </div></td>
  </tr><?php endforeach; ?><?php if(!$codes): ?><tr><td colspan="7" class="empty">لا توجد أكواد</td></tr><?php endif; ?>
  </tbody></table></div>
</section>

<?php elseif ($tab==='devices'): ?>
<section class="panel" style="margin-top:0"><div class="panel-head"><h3>الأجهزة المرتبطة</h3><span class="muted"><?= count($devices) ?> جهاز</span></div>
<div class="table-wrap"><table><thead><tr><th>الكود</th><th>معرف الجهاز</th><th>الاسم</th><th>iOS</th><th>نسخة التطبيق</th><th>آخر اتصال</th><th>إجراء</th></tr></thead><tbody>
<?php foreach($devices as $row): ?><tr><td class="code"><?= e($row['code']) ?></td><td class="code"><?= e(clip($row['udid'],24)) ?>…</td><td><?= e($row['device_name']) ?></td><td><?= e($row['ios_version']) ?></td><td><?= e($row['app_version']) ?></td><td><?= e($row['last_seen']) ?></td><td><form method="post" onsubmit="return confirm('فصل هذا الجهاز؟')"><input type="hidden" name="csrf" value="<?= e($csrf) ?>"><input type="hidden" name="device_id" value="<?= (int)$row['id'] ?>"><button class="btn btn-danger btn-sm" name="disconnect_device">فصل</button></form></td></tr><?php endforeach; ?><?php if(!$devices): ?><tr><td colspan="7" class="empty">لا توجد أجهزة مرتبطة</td></tr><?php endif; ?>
</tbody></table></div></section>

<?php elseif ($tab==='logs'): ?>
<section class="panel" style="margin-top:0"><div class="panel-head"><div><h3>سجل العمليات</h3><p class="muted">آخر 300 حدث</p></div><form method="post" onsubmit="return confirm('مسح السجل؟')"><input type="hidden" name="csrf" value="<?= e($csrf) ?>"><button class="btn btn-danger btn-sm" name="clear_logs">مسح السجل</button></form></div>
<div class="table-wrap"><table><thead><tr><th>الوقت</th><th>العملية</th><th>النتيجة</th><th>الكود</th><th>الجهاز</th><th>الرسالة</th><th>IP</th></tr></thead><tbody>
<?php foreach($logs as $row): ?><tr><td><?= e($row['created_at']) ?></td><td><?= e($row['action']) ?></td><td><span class="badge <?= e($row['result']) ?>"><?= e($row['result']) ?></span></td><td class="code"><?= e($row['code']) ?></td><td class="code"><?= e(clip((string)$row['udid'],18)) ?></td><td><?= e($row['message']) ?></td><td><?= e($row['ip']) ?></td></tr><?php endforeach; ?><?php if(!$logs): ?><tr><td colspan="7" class="empty">السجل فارغ</td></tr><?php endif; ?>
</tbody></table></div></section>

<?php elseif ($tab==='settings'): ?>
<section class="panel" style="margin-top:0"><div class="panel-head"><div><h3>إعدادات الخدمة</h3><p class="muted">تُطبق مباشرة على API</p></div></div>
<form method="post"><input type="hidden" name="csrf" value="<?= e($csrf) ?>"><div class="form-grid">
<div class="switch-row"><span>وضع الصيانة</span><input type="checkbox" name="maintenance" <?= $settings['maintenance']==='1'?'checked':'' ?> style="width:auto"></div>
<div class="switch-row"><span>تحديث إجباري</span><input type="checkbox" name="force_update" <?= $settings['force_update']==='1'?'checked':'' ?> style="width:auto"></div>
<div class="field"><label>أقل إصدار مسموح</label><input name="minimum_version" value="<?= e($settings['minimum_version']) ?>"></div>
<div class="field" style="grid-column:span 2"><label>رسالة الخادم</label><textarea name="server_message" rows="3"><?= e($settings['server_message']) ?></textarea></div>
<button class="btn btn-primary" name="save_settings">حفظ الإعدادات</button>
</div></form></section>
<section class="panel"><div class="panel-head"><div><h3>النسخ الاحتياطي</h3><p class="muted">تنزيل قاعدة SQLite الحالية</p></div><form method="post"><input type="hidden" name="csrf" value="<?= e($csrf) ?>"><button class="btn" name="download_backup">تنزيل النسخة</button></form></div></section>

<?php elseif ($tab==='api'): ?>
<section class="panel" style="margin-top:0"><div class="panel-head"><div><h3>WolFox Key API</h3><p class="muted">Secure • Fast • Reliable</p></div><span class="server-ok">● Online</span></div>
<div class="api-card"><span class="method">POST</span><code>/activation/api/activate.php</code><p class="muted">تفعيل الكود وربط الجهاز</p></div>
<div class="api-card"><span class="method">POST</span><code>/activation/api/verify.php</code><p class="muted">التحقق من الجلسة</p></div>
<div class="api-card"><span class="method">POST</span><code>/activation/api/heartbeat.php</code><p class="muted">تحديث آخر اتصال للجهاز</p></div>
<div class="api-card"><span class="method">POST</span><code>/activation/api/reset.php</code><p class="muted">فصل جهاز بمفتاح إدارة من الخادم فقط</p></div>
<p class="muted">مفتاح الإدارة مخفي ولا يتم إرساله إلى المتصفح.</p></section>
<?php endif; ?>
</div>
<?php endif; ?>
</body>
</html>
