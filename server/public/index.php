<?php
/**
 * لوحة التحكم الرئيسية — GPS Plus Admin Dashboard
 *
 * متغيرات البيئة المطلوبة:
 *   GPSQ_ADMIN_PASSWORD  — كلمة مرور الدخول للوحة
 *   GPSQ_API_KEY         — مفتاح API (للعرض/النسخ في اللوحة)
 */

require_once __DIR__ . '/api/config.php';

session_start();

// توليد CSRF token للجلسة إن لم يكن موجوداً
if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}
$csrfToken = $_SESSION['csrf_token'];

/** التحقق من CSRF token في الطلبات POST المصادق عليها */
function verifyCsrf(): void
{
    $provided = $_POST['csrf_token'] ?? '';
    if (!hash_equals($_SESSION['csrf_token'] ?? '', $provided)) {
        http_response_code(403);
        exit('طلب غير صالح (CSRF)');
    }
}

// ============================================================
// المصادقة
// ============================================================
$loginError = '';

if (isset($_POST['logout'])) {
    verifyCsrf();
    session_destroy();
    header('Location: index.php');
    exit;
}

if (isset($_POST['password'])) {
    $adminPass = GPSQ_ADMIN_PASSWORD;
    if ($adminPass !== '' && hash_equals($adminPass, $_POST['password'])) {
        $_SESSION['auth'] = true;
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
        $csrfToken = $_SESSION['csrf_token'];
        header('Location: index.php');
        exit;
    }
    $loginError = 'كلمة المرور غير صحيحة';
}

$isAuth = !empty($_SESSION['auth']);

// ============================================================
// إجراءات لوحة التحكم (تتطلب المصادقة)
// ============================================================
$actionMsg = '';

if ($isAuth) {
    $db = getDB();

    // إضافة كود جديد
    if (isset($_POST['add_code'])) {
        verifyCsrf();
        $newCode = strtoupper(trim($_POST['new_code'] ?? ''));
        if (preg_match('/^[A-Z0-9]{4,32}$/', $newCode)) {
            try {
                $db->prepare("INSERT INTO codes (code) VALUES (?)")->execute([$newCode]);
                $actionMsg = "✅ تمت إضافة الكود: $newCode";
            } catch (Exception $e) {
                $actionMsg = '⚠️ الكود موجود مسبقاً أو حدث خطأ';
            }
        } else {
            $actionMsg = '⚠️ الكود يجب أن يحتوي على 4-32 حرف/رقم فقط (A-Z, 0-9)';
        }
    }

    // تغيير حالة كود
    if (isset($_POST['change_status'])) {
        verifyCsrf();
        $codeTarget = trim($_POST['code_target'] ?? '');
        $newStatus  = trim($_POST['new_status'] ?? '');
        $allowed    = ['unused', 'linked', 'expired', 'closed'];
        if ($codeTarget && in_array($newStatus, $allowed, true)) {
            $db->prepare("UPDATE codes SET status=? WHERE code=?")->execute([$newStatus, $codeTarget]);
            $actionMsg = "✅ تم تغيير حالة الكود إلى: $newStatus";
        }
    }

    // حذف كود
    if (isset($_POST['delete_code'])) {
        verifyCsrf();
        $codeDel = trim($_POST['code_del'] ?? '');
        if ($codeDel) {
            $db->prepare("DELETE FROM codes WHERE code=?")->execute([$codeDel]);
            $db->prepare("DELETE FROM devices WHERE code=?")->execute([$codeDel]);
            $actionMsg = "🗑️ تم حذف الكود: $codeDel";
        }
    }
}

// ============================================================
// جلب البيانات للعرض
// ============================================================
$codes   = [];
$stats   = [];
$chartData = [];

if ($isAuth) {
    $db = getDB();

    // فلتر الحالة
    $filterStatus = $_GET['status'] ?? 'all';
    $allowed      = ['all', 'unused', 'linked', 'expired', 'closed'];
    if (!in_array($filterStatus, $allowed, true)) {
        $filterStatus = 'all';
    }

    if ($filterStatus === 'all') {
        $codes = $db->query("SELECT * FROM codes ORDER BY created_at DESC")->fetchAll();
    } else {
        $stmt = $db->prepare("SELECT * FROM codes WHERE status=? ORDER BY created_at DESC");
        $stmt->execute([$filterStatus]);
        $codes = $stmt->fetchAll();
    }

    // إحصائيات
    $counts = $db->query("SELECT status, COUNT(*) as cnt FROM codes GROUP BY status")->fetchAll();
    $statsMap = ['unused' => 0, 'linked' => 0, 'expired' => 0, 'closed' => 0];
    foreach ($counts as $c) {
        $statsMap[$c['status']] = (int)$c['cnt'];
    }
    $statsMap['total'] = array_sum($statsMap);

    // عدد الأجهزة الفريدة (installs)
    $statsMap['installs'] = (int)$db->query("SELECT COUNT(DISTINCT udid) FROM devices")->fetchColumn();

    $stats = $statsMap;

    // بيانات الرسم البياني — عدد التفعيلات في آخر 30 يوم
    $chartRows = $db->query("
        SELECT date(activated_at) as day, COUNT(*) as cnt
        FROM codes
        WHERE activated_at IS NOT NULL
          AND activated_at >= datetime('now', '-30 days')
        GROUP BY day
        ORDER BY day ASC
    ")->fetchAll();
    $chartData = $chartRows;
}

// ============================================================
// دوال مساعدة للعرض
// ============================================================
function statusBadge(string $status): string
{
    $map = [
        'unused'  => ['label' => 'غير مستخدم', 'class' => 'badge-unused'],
        'linked'  => ['label' => 'مرتبط',       'class' => 'badge-linked'],
        'expired' => ['label' => 'منتهي',        'class' => 'badge-expired'],
        'closed'  => ['label' => 'مغلق',         'class' => 'badge-closed'],
    ];
    $s = $map[$status] ?? ['label' => $status, 'class' => 'badge-unused'];
    return '<span class="badge ' . $s['class'] . '">' . htmlspecialchars($s['label']) . '</span>';
}

function e(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
}

$apiKeyDisplay = GPSQ_API_KEY ? substr(GPSQ_API_KEY, 0, 6) . '••••••••' : '(غير محدد)';
$apiKeyFull    = GPSQ_API_KEY ?: '';
?>
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>GPS Plus — لوحة التحكم</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<style>
  :root {
    --bg:       #0f0f14;
    --surface:  #1a1a24;
    --card:     #22223a;
    --border:   #2e2e48;
    --accent:   #7c6fff;
    --accent2:  #5b4fcf;
    --text:     #e5e7eb;
    --muted:    #9ca3af;
    --danger:   #ef4444;
    --success:  #22c55e;
    --warning:  #f59e0b;
    --info:     #3b82f6;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: var(--bg);
    color: var(--text);
    font-family: 'Segoe UI', Tahoma, Arial, sans-serif;
    font-size: 15px;
    min-height: 100vh;
  }
  a { color: var(--accent); text-decoration: none; }

  /* ── الترويسة ── */
  .topbar {
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    padding: 12px 24px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 10px;
  }
  .topbar h1 { font-size: 1.2rem; color: var(--accent); }
  .topbar-actions { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }

  /* ── بطاقات الإحصاء ── */
  .stat-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
    gap: 14px;
    padding: 20px 24px 0;
  }
  .stat-card {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 16px;
    text-align: center;
  }
  .stat-card .val { font-size: 2rem; font-weight: 700; }
  .stat-card .lbl { color: var(--muted); font-size: 0.85rem; margin-top: 4px; }
  .val-total   { color: var(--text); }
  .val-linked  { color: var(--success); }
  .val-unused  { color: var(--info); }
  .val-installs{ color: var(--accent); }

  /* ── التبويبات ── */
  .tabs {
    display: flex;
    gap: 4px;
    padding: 16px 24px 0;
    border-bottom: 1px solid var(--border);
  }
  .tab-btn {
    padding: 8px 18px;
    border-radius: 8px 8px 0 0;
    border: 1px solid transparent;
    background: transparent;
    color: var(--muted);
    cursor: pointer;
    font-size: 0.95rem;
    transition: .2s;
  }
  .tab-btn.active, .tab-btn:hover {
    background: var(--card);
    border-color: var(--border);
    color: var(--text);
  }
  .tab-btn.active { color: var(--accent); border-bottom-color: var(--card); }
  .tab-panel { display: none; padding: 20px 24px; }
  .tab-panel.active { display: block; }

  /* ── شريط الأدوات ── */
  .toolbar {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
    align-items: center;
    margin-bottom: 16px;
  }
  .filter-btns { display: flex; gap: 6px; flex-wrap: wrap; }
  .filter-btn {
    padding: 6px 14px;
    border-radius: 20px;
    border: 1px solid var(--border);
    background: var(--surface);
    color: var(--text);
    cursor: pointer;
    font-size: 0.85rem;
    transition: .2s;
  }
  .filter-btn:hover, .filter-btn.active {
    background: var(--accent);
    border-color: var(--accent);
    color: #fff;
  }

  /* ── زر ── */
  .btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 7px 16px;
    border-radius: 8px;
    border: none;
    cursor: pointer;
    font-size: 0.9rem;
    font-weight: 600;
    transition: .2s;
  }
  .btn-primary { background: var(--accent); color: #fff; }
  .btn-primary:hover { background: var(--accent2); }
  .btn-danger  { background: var(--danger); color: #fff; }
  .btn-danger:hover  { opacity: .85; }
  .btn-ghost {
    background: transparent;
    border: 1px solid var(--border);
    color: var(--muted);
  }
  .btn-ghost:hover { border-color: var(--accent); color: var(--accent); }
  .btn-sm { padding: 4px 10px; font-size: 0.8rem; }

  /* ── حقول الإدخال ── */
  input[type=text], input[type=password], select {
    background: var(--surface);
    border: 1px solid var(--border);
    color: var(--text);
    border-radius: 8px;
    padding: 8px 12px;
    font-size: 0.9rem;
    outline: none;
    width: 100%;
  }
  input:focus, select:focus { border-color: var(--accent); }

  /* ── الجدول ── */
  .table-wrap { overflow-x: auto; border-radius: 10px; border: 1px solid var(--border); }
  table { width: 100%; border-collapse: collapse; }
  thead th {
    background: var(--card);
    padding: 11px 14px;
    text-align: right;
    font-weight: 600;
    font-size: 0.85rem;
    color: var(--muted);
    border-bottom: 1px solid var(--border);
    white-space: nowrap;
  }
  tbody tr:nth-child(even) { background: rgba(255,255,255,.02); }
  tbody tr:hover { background: rgba(124,111,255,.07); }
  tbody td {
    padding: 10px 14px;
    border-bottom: 1px solid var(--border);
    font-size: 0.88rem;
    vertical-align: middle;
  }
  tbody tr:last-child td { border-bottom: none; }

  /* ── الشارات ── */
  .badge {
    display: inline-block;
    padding: 3px 10px;
    border-radius: 20px;
    font-size: 0.78rem;
    font-weight: 600;
    white-space: nowrap;
  }
  .badge-unused  { background: rgba(59,130,246,.2);  color: #93c5fd; }
  .badge-linked  { background: rgba(34,197,94,.2);   color: #86efac; }
  .badge-expired { background: rgba(245,158,11,.2);  color: #fcd34d; }
  .badge-closed  { background: rgba(107,114,128,.2); color: #9ca3af; }

  /* ── مفتاح API ── */
  .api-key-row {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 14px 18px;
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
    margin-bottom: 16px;
  }
  .api-key-val {
    font-family: monospace;
    font-size: 1rem;
    color: var(--accent);
    flex: 1;
    word-break: break-all;
  }

  /* ── نموذج إضافة كود ── */
  .add-form {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 16px 18px;
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
    align-items: flex-end;
    margin-bottom: 16px;
  }
  .add-form .field { flex: 1; min-width: 180px; }
  .add-form label { display: block; font-size: 0.82rem; color: var(--muted); margin-bottom: 5px; }

  /* ── رسائل التنبيه ── */
  .alert {
    border-radius: 8px;
    padding: 10px 16px;
    margin-bottom: 14px;
    font-size: 0.9rem;
  }
  .alert-info { background: rgba(59,130,246,.15); border: 1px solid rgba(59,130,246,.3); }
  .alert-err  { background: rgba(239,68,68,.15);  border: 1px solid rgba(239,68,68,.3);  }

  /* ── صفحة تسجيل الدخول ── */
  .login-wrap {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 20px;
  }
  .login-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 14px;
    padding: 36px 32px;
    width: 100%;
    max-width: 380px;
  }
  .login-card h2 { color: var(--accent); margin-bottom: 24px; text-align: center; }
  .login-card .field { margin-bottom: 16px; }
  .login-card label { display: block; margin-bottom: 6px; font-size: 0.9rem; color: var(--muted); }

  /* ── الرسم البياني ── */
  .chart-wrap {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 20px;
    margin-top: 20px;
  }
  .chart-wrap h3 { margin-bottom: 14px; font-size: 0.95rem; color: var(--muted); }

  /* ── Responsive ── */
  @media (max-width: 600px) {
    .topbar, .toolbar { flex-direction: column; align-items: flex-start; }
    .tab-panel { padding: 14px 12px; }
    .stat-grid { padding: 14px 12px 0; }
    .tabs { padding: 12px 12px 0; }
  }

  /* ── copy-btn done state ── */
  .copy-btn.done { background: rgba(34,197,94,.25) !important; color: #86efac !important; }
</style>
</head>
<body>

<?php if (!$isAuth): ?>
<!-- ===== صفحة تسجيل الدخول ===== -->
<div class="login-wrap">
  <div class="login-card">
    <h2>🔐 لوحة التحكم</h2>
    <p style="text-align:center;color:var(--muted);margin-bottom:24px;font-size:.9rem">GPS Plus Admin</p>
    <?php if ($loginError): ?>
      <div class="alert alert-err"><?= e($loginError) ?></div>
    <?php endif; ?>
    <form method="post">
      <div class="field">
        <label for="password">كلمة المرور</label>
        <input type="password" id="password" name="password" placeholder="أدخل كلمة المرور" autofocus required>
      </div>
      <button type="submit" class="btn btn-primary" style="width:100%;justify-content:center;margin-top:8px">دخول</button>
    </form>
  </div>
</div>

<?php else: ?>
<!-- ===== لوحة التحكم ===== -->

<div class="topbar">
  <h1>🛰️ GPS Plus — لوحة التحكم</h1>
  <div class="topbar-actions">
    <?php if ($apiKeyFull): ?>
    <span class="api-key-val" style="font-size:.85rem">🔑 <?= e($apiKeyDisplay) ?></span>
    <button class="btn btn-ghost btn-sm copy-btn" data-copy="<?= e($apiKeyFull) ?>">نسخ المفتاح</button>
    <?php endif; ?>
    <form method="post" style="margin:0">
      <input type="hidden" name="csrf_token" value="<?= e($csrfToken) ?>">
      <button name="logout" class="btn btn-ghost btn-sm">خروج</button>
    </form>
  </div>
</div>

<?php if ($actionMsg): ?>
<div class="alert alert-info" style="margin:14px 24px 0"><?= e($actionMsg) ?></div>
<?php endif; ?>

<!-- بطاقات الإحصاء -->
<div class="stat-grid">
  <div class="stat-card"><div class="val val-total"><?= $stats['total'] ?></div><div class="lbl">إجمالي الأكواد</div></div>
  <div class="stat-card"><div class="val val-unused"><?= $stats['unused'] ?></div><div class="lbl">غير مستخدم</div></div>
  <div class="stat-card"><div class="val val-linked"><?= $stats['linked'] ?></div><div class="lbl">مرتبط</div></div>
  <div class="stat-card"><div class="val" style="color:var(--warning)"><?= $stats['expired'] ?></div><div class="lbl">منتهي</div></div>
  <div class="stat-card"><div class="val" style="color:var(--muted)"><?= $stats['closed'] ?></div><div class="lbl">مغلق</div></div>
  <div class="stat-card"><div class="val val-installs"><?= $stats['installs'] ?></div><div class="lbl">أجهزة مثبَّتة</div></div>
</div>

<!-- التبويبات -->
<div class="tabs">
  <button class="tab-btn active" onclick="switchTab('codes',this)">📋 الأكواد</button>
  <button class="tab-btn" onclick="switchTab('stats',this)">📊 الإحصائيات</button>
</div>

<!-- ===== تبويب الأكواد ===== -->
<div class="tab-panel active" id="tab-codes">

  <!-- إضافة كود -->
  <form method="post" class="add-form">
    <input type="hidden" name="csrf_token" value="<?= e($csrfToken) ?>">
    <div class="field">
      <label for="new_code">إضافة كود جديد (حروف وأرقام إنجليزية 4-32 خانة)</label>
      <input type="text" id="new_code" name="new_code" placeholder="مثال: ABCD1234" maxlength="32" style="text-transform:uppercase">
    </div>
    <button name="add_code" class="btn btn-primary">➕ إضافة</button>
  </form>

  <!-- الفلاتر وزر النسخ المتعدد -->
  <div class="toolbar">
    <div class="filter-btns">
      <?php
      $filters = ['all' => 'الكل', 'unused' => 'غير مستخدم', 'linked' => 'مرتبط', 'expired' => 'منتهي', 'closed' => 'مغلق'];
      foreach ($filters as $val => $lbl):
      ?>
      <a href="?status=<?= $val ?>" class="filter-btn <?= $filterStatus === $val ? 'active' : '' ?>"><?= $lbl ?></a>
      <?php endforeach; ?>
    </div>
    <button class="btn btn-primary btn-sm copy-selected">نسخ المحدد</button>
  </div>

  <!-- الجدول -->
  <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th><input type="checkbox" id="check-all" title="تحديد الكل"></th>
          <th>الكود</th>
          <th>الحالة</th>
          <th>الجهاز / UDID</th>
          <th>تاريخ الإنشاء</th>
          <th>آخر تفعيل</th>
          <th>إجراء</th>
        </tr>
      </thead>
      <tbody>
      <?php if (empty($codes)): ?>
        <tr><td colspan="7" style="text-align:center;color:var(--muted);padding:30px">لا توجد أكواد<?= $filterStatus !== 'all' ? ' بهذه الحالة' : '' ?></td></tr>
      <?php else: foreach ($codes as $row): ?>
        <tr>
          <td><input type="checkbox" class="row-check" data-code="<?= e($row['code']) ?>"></td>
          <td>
            <span style="font-family:monospace;font-size:.95rem"><?= e($row['code']) ?></span>
            <button class="btn btn-ghost btn-sm copy-btn" style="margin-right:6px" data-copy="<?= e($row['code']) ?>">نسخ</button>
          </td>
          <td><?= statusBadge($row['status']) ?></td>
          <td style="max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="<?= e($row['udid'] ?? '') ?>">
            <?php if ($row['udid']): ?>
              <span style="font-size:.8rem;color:var(--muted)"><?= e($row['device_name'] ?? '') ?></span>
              <br><span style="font-family:monospace;font-size:.75rem;color:var(--muted)"><?= e(substr($row['udid'], 0, 20)) ?>…</span>
            <?php else: ?>
              <span style="color:var(--muted)">—</span>
            <?php endif; ?>
          </td>
          <td style="color:var(--muted);font-size:.82rem;white-space:nowrap"><?= e(substr($row['created_at'] ?? '', 0, 16)) ?></td>
          <td style="color:var(--muted);font-size:.82rem;white-space:nowrap"><?= $row['activated_at'] ? e(substr($row['activated_at'], 0, 16)) : '<span style="color:var(--border)">—</span>' ?></td>
          <td>
            <!-- تغيير الحالة -->
            <form method="post" style="display:inline-flex;gap:4px;align-items:center">
              <input type="hidden" name="csrf_token" value="<?= e($csrfToken) ?>">
              <input type="hidden" name="code_target" value="<?= e($row['code']) ?>">
              <select name="new_status" style="padding:3px 6px;font-size:.8rem;width:auto">
                <?php foreach (['unused','linked','expired','closed'] as $s): ?>
                <option value="<?= $s ?>" <?= $row['status'] === $s ? 'selected' : '' ?>><?= ['unused'=>'غير مستخدم','linked'=>'مرتبط','expired'=>'منتهي','closed'=>'مغلق'][$s] ?></option>
                <?php endforeach; ?>
              </select>
              <button name="change_status" class="btn btn-ghost btn-sm">حفظ</button>
            </form>
            <!-- حذف -->
            <form method="post" style="display:inline" onsubmit="return confirm('حذف الكود <?= e(addslashes($row['code'])) ?>؟')">
              <input type="hidden" name="csrf_token" value="<?= e($csrfToken) ?>">
              <input type="hidden" name="code_del" value="<?= e($row['code']) ?>">
              <button name="delete_code" class="btn btn-danger btn-sm">🗑️</button>
            </form>
          </td>
        </tr>
      <?php endforeach; endif; ?>
      </tbody>
    </table>
  </div><!-- .table-wrap -->
</div><!-- #tab-codes -->

<!-- ===== تبويب الإحصائيات ===== -->
<div class="tab-panel" id="tab-stats">
  <p style="color:var(--muted);margin-bottom:16px">ملخص أداء الأكواد والأجهزة</p>

  <div class="stat-grid" style="padding:0;margin-bottom:20px">
    <div class="stat-card"><div class="val val-total"><?= $stats['total'] ?></div><div class="lbl">إجمالي الأكواد</div></div>
    <div class="stat-card"><div class="val val-linked"><?= $stats['linked'] ?></div><div class="lbl">أكواد مستخدمة</div></div>
    <div class="stat-card"><div class="val val-unused"><?= $stats['unused'] ?></div><div class="lbl">أكواد غير مستخدمة</div></div>
    <div class="stat-card"><div class="val val-installs"><?= $stats['installs'] ?></div><div class="lbl">أجهزة مثبَّتة (installs)</div></div>
  </div>

  <div class="chart-wrap">
    <h3>📈 التفعيلات في آخر 30 يوم</h3>
    <canvas id="activationsChart" height="80"></canvas>
  </div>
</div><!-- #tab-stats -->

<script src="assets/panel.js"></script>
<script>
// ── إدارة التبويبات ──
function switchTab(id, btn) {
  document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
  document.getElementById('tab-' + id).classList.add('active');
  btn.classList.add('active');
}

// ── تحديد/إلغاء الكل ──
document.getElementById('check-all')?.addEventListener('change', function() {
  document.querySelectorAll('.row-check').forEach(c => c.checked = this.checked);
});

// ── الرسم البياني ──
const chartData = <?= json_encode($chartData, JSON_UNESCAPED_UNICODE) ?>;
if (chartData.length > 0) {
  const ctx = document.getElementById('activationsChart').getContext('2d');
  new Chart(ctx, {
    type: 'bar',
    data: {
      labels: chartData.map(r => r.day),
      datasets: [{
        label: 'تفعيلات',
        data: chartData.map(r => r.cnt),
        backgroundColor: 'rgba(124,111,255,.6)',
        borderColor: 'rgba(124,111,255,1)',
        borderWidth: 1,
        borderRadius: 4,
      }]
    },
    options: {
      plugins: {
        legend: { labels: { color: '#9ca3af' } }
      },
      scales: {
        x: { ticks: { color: '#9ca3af' }, grid: { color: '#2e2e48' } },
        y: { ticks: { color: '#9ca3af', stepSize: 1 }, grid: { color: '#2e2e48' }, beginAtZero: true }
      }
    }
  });
} else {
  document.getElementById('activationsChart').parentElement.insertAdjacentHTML(
    'beforeend',
    '<p style="color:var(--muted);text-align:center;padding:20px 0">لا توجد تفعيلات بعد</p>'
  );
  document.getElementById('activationsChart').style.display = 'none';
}
</script>

<?php endif; ?>
</body>
</html>
