<?php
require_once __DIR__ . '/api/config.php';
session_start();

if (empty($_SESSION['auth'])) {
    header('Location: index.php');
    exit;
}

function e(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
}

$db = getDB();
$search = trim($_GET['q'] ?? '');
$params = [];
$sql = "SELECT d.*, c.status, c.activated_at FROM devices d LEFT JOIN codes c ON c.code = d.code";

if ($search !== '') {
    $sql .= " WHERE d.code LIKE ? OR d.udid LIKE ? OR COALESCE(d.device_name, '') LIKE ?";
    $needle = '%' . $search . '%';
    $params = [$needle, $needle, $needle];
}

$sql .= " ORDER BY d.last_seen DESC";
$stmt = $db->prepare($sql);
$stmt->execute($params);
$devices = $stmt->fetchAll();
$totalDevices = (int)$db->query("SELECT COUNT(*) FROM devices")->fetchColumn();
$uniqueDevices = (int)$db->query("SELECT COUNT(DISTINCT udid) FROM devices")->fetchColumn();
$linkedCodes = (int)$db->query("SELECT COUNT(DISTINCT code) FROM devices")->fetchColumn();
?>
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>GPS Plus — الأجهزة</title>
<style>
:root{--bg:#05080d;--surface:#0b1620;--card:#102638;--border:rgba(25,170,245,.28);--primary:#19aaf5;--accent:#7a5cff;--text:#f7fbff;--muted:#9ba8b5;--success:#22c55e;--warning:#f59e0b;--radius:20px}*{box-sizing:border-box}body{margin:0;min-height:100vh;background:radial-gradient(circle at 85% 10%,rgba(25,170,245,.15),transparent 28%),radial-gradient(circle at 10% 70%,rgba(122,92,255,.16),transparent 30%),linear-gradient(180deg,#04070c,#07121c,#04070c);color:var(--text);font-family:Tahoma,Arial,sans-serif}.topbar{position:sticky;top:0;z-index:10;display:flex;justify-content:space-between;align-items:center;gap:12px;padding:14px 22px;background:rgba(5,8,13,.88);backdrop-filter:blur(16px);border-bottom:1px solid var(--border)}.brand{font-weight:800}.nav{display:flex;gap:8px;flex-wrap:wrap}.btn{display:inline-flex;align-items:center;justify-content:center;padding:9px 14px;border-radius:12px;border:1px solid var(--border);background:var(--surface);color:var(--text);text-decoration:none;cursor:pointer}.btn:hover,.btn.active{border-color:var(--primary);color:var(--primary)}.wrap{padding:22px;max-width:1500px;margin:auto}.hero{display:flex;justify-content:space-between;align-items:center;gap:16px;margin-bottom:18px}.hero h1{margin:0 0 6px}.muted{color:var(--muted)}.stats{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;margin-bottom:18px}.card{background:linear-gradient(145deg,rgba(16,38,56,.94),rgba(11,22,32,.94));border:1px solid var(--border);border-radius:var(--radius);padding:18px;box-shadow:0 18px 50px rgba(0,0,0,.22)}.stat-value{font-size:2rem;font-weight:800;color:var(--primary)}.search{display:flex;gap:10px;margin-bottom:14px}.search input{flex:1;background:var(--surface);color:var(--text);border:1px solid var(--border);border-radius:13px;padding:12px 14px;outline:none}.search input:focus{border-color:var(--primary)}.table-wrap{overflow:auto;border:1px solid var(--border);border-radius:var(--radius);background:rgba(11,22,32,.9)}table{width:100%;border-collapse:collapse;min-width:920px}th,td{padding:13px 14px;text-align:right;border-bottom:1px solid rgba(255,255,255,.06)}th{background:rgba(16,38,56,.95);color:var(--muted);font-size:.86rem}tr:hover td{background:rgba(25,170,245,.04)}.secret{font-family:monospace}.secret.masked{filter:blur(6px);user-select:none}.actions{display:flex;gap:6px;flex-wrap:wrap}.badge{padding:4px 9px;border-radius:20px;font-size:.78rem;background:rgba(34,197,94,.16);color:#86efac}.empty{text-align:center;padding:35px;color:var(--muted)}@media(max-width:760px){.topbar,.hero{align-items:flex-start;flex-direction:column}.wrap{padding:14px}.stats{grid-template-columns:1fr}.search{flex-direction:column}.nav{width:100%}.nav .btn{flex:1}}
</style>
</head>
<body>
<header class="topbar">
  <div class="brand">🛰️ GPS Plus Admin</div>
  <nav class="nav">
    <a class="btn" href="index.php">الأكواد والإحصائيات</a>
    <a class="btn active" href="devices.php">الأجهزة</a>
  </nav>
</header>
<main class="wrap">
  <section class="hero">
    <div><h1>إدارة الأجهزة</h1><div class="muted">صفحة مستقلة لعرض الأجهزة المرتبطة دون تغيير الربط أو منطق التفعيل.</div></div>
  </section>
  <section class="stats">
    <div class="card"><div class="stat-value"><?= $totalDevices ?></div><div class="muted">إجمالي السجلات</div></div>
    <div class="card"><div class="stat-value"><?= $uniqueDevices ?></div><div class="muted">أجهزة فريدة</div></div>
    <div class="card"><div class="stat-value"><?= $linkedCodes ?></div><div class="muted">أكواد مرتبطة</div></div>
  </section>
  <form class="search" method="get">
    <input name="q" value="<?= e($search) ?>" placeholder="ابحث بالكود أو UDID أو اسم الجهاز">
    <button class="btn" type="submit">بحث</button>
    <?php if ($search !== ''): ?><a class="btn" href="devices.php">مسح</a><?php endif; ?>
  </form>
  <div class="table-wrap">
    <table>
      <thead><tr><th>الكود</th><th>اسم الجهاز</th><th>UDID</th><th>الحالة</th><th>آخر تفعيل</th><th>إجراءات</th></tr></thead>
      <tbody>
      <?php if (!$devices): ?>
        <tr><td colspan="6" class="empty">لا توجد أجهزة مطابقة.</td></tr>
      <?php else: foreach ($devices as $device): ?>
        <tr>
          <td><span class="secret"><?= e($device['code'] ?? '') ?></span></td>
          <td><?= e($device['device_name'] ?? 'غير معروف') ?></td>
          <td><span class="secret masked" data-secret><?= e($device['udid'] ?? '') ?></span></td>
          <td><span class="badge"><?= e($device['status'] ?? 'linked') ?></span></td>
          <td class="muted"><?= e(substr($device['activated_at'] ?? '', 0, 16)) ?: '—' ?></td>
          <td><div class="actions"><button class="btn toggle-secret" type="button">إظهار</button><button class="btn copy-btn" type="button" data-copy="<?= e($device['udid'] ?? '') ?>">نسخ UDID</button><button class="btn copy-btn" type="button" data-copy="<?= e($device['code'] ?? '') ?>">نسخ الكود</button></div></td>
        </tr>
      <?php endforeach; endif; ?>
      </tbody>
    </table>
  </div>
</main>
<script src="assets/panel.js"></script>
</body>
</html>
