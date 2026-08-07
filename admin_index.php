<?php
/**
 * WLLFox GPS - Admin Dashboard (Main Index)
 * Copyright (c) 2026 LaylaStore
 */

session_start();
$admin_pass = "admin123"; // كلمة المرور الافتراضية
$dbFile = '../api/database.json'; // المسار إلى قاعدة البيانات في مجلد api

// التأكد من وجود مجلد api وقاعدة البيانات
if (!file_exists('../api')) {
    mkdir('../api', 0755, true);
}
if (!file_exists($dbFile)) {
    file_put_contents($dbFile, json_encode(['codes' => []]));
}

$db = json_decode(file_get_contents($dbFile), true);

if (isset($_GET['logout'])) {
    session_destroy();
    header("Location: ./");
    exit;
}

if (!isset($_SESSION['logged_in'])) {
    if (isset($_POST['pass']) && $_POST['pass'] === $admin_pass) {
        $_SESSION['logged_in'] = true;
    } else {
        die('
        <body style="background:#070b18;color:white;display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;margin:0;">
            <form method="POST" style="background:#0e1528;padding:40px;border-radius:20px;border:1px solid #c9a227;box-shadow: 0 0 20px rgba(201,162,39,0.2);width:300px;">
                <h2 style="color:#c9a227;text-align:center;margin-bottom:30px;">WLLFox Admin</h2>
                <div style="margin-bottom:20px;">
                    <label style="display:block;margin-bottom:10px;font-size:14px;color:#c9a227;">كلمة المرور</label>
                    <input type="password" name="pass" placeholder="••••••••" style="width:100%;padding:12px;background:#111a30;border:1px solid #c9a22733;border-radius:8px;color:white;box-sizing:border-box;outline:none;">
                </div>
                <button type="submit" style="width:100%;padding:12px;background:#c9a227;border:none;border-radius:8px;color:#070b18;font-weight:bold;cursor:pointer;transition:0.3s;">دخول النظام</button>
            </form>
        </body>');
    }
}

// إضافة كود جديد
if (isset($_POST['add_code'])) {
    $days = intval($_POST['days'] ?: 30);
    $code = strtoupper(substr(md5(time().rand()), 0, 4) . '-' . substr(md5(time().rand()), 4, 4) . '-' . substr(md5(time().rand()), 8, 4));
    $db['codes'][$code] = [
        'udid' => '',
        'expiry' => date('Y-m-d', strtotime("+$days days")),
        'status' => 'active',
        'created_at' => date('Y-m-d H:i:s')
    ];
    file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
}

// حذف كود
if (isset($_GET['delete'])) {
    unset($db['codes'][$_GET['delete']]);
    file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
    header("Location: ./");
}

// إعادة ضبط UDID
if (isset($_GET['reset'])) {
    $db['codes'][$_GET['reset']]['udid'] = '';
    file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
    header("Location: ./");
}

?>
<!DOCTYPE html>
<html dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WLLFox GPS - لوحة التحكم الإدارية</title>
    <style>
        body { background: #070b18; color: #e1e1e1; font-family: 'Cairo', sans-serif; margin: 0; padding: 0; }
        .sidebar { width: 250px; background: #0e1528; height: 100vh; position: fixed; border-left: 1px solid #c9a22733; padding: 20px; box-sizing: border-box; }
        .main-content { margin-right: 250px; padding: 40px; }
        .logo { color: #c9a227; font-size: 24px; font-weight: bold; text-align: center; margin-bottom: 40px; border-bottom: 1px solid #c9a22733; padding-bottom: 20px; }
        .nav-item { display: block; padding: 12px; color: #e1e1e1; text-decoration: none; border-radius: 8px; margin-bottom: 10px; transition: 0.3s; }
        .nav-item:hover, .nav-item.active { background: #c9a22722; color: #c9a227; }
        .card { background: #0e1528; border-radius: 15px; padding: 25px; border: 1px solid #c9a22722; margin-bottom: 30px; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { background: #111a30; padding: 20px; border-radius: 12px; border-right: 4px solid #c9a227; }
        .stat-value { font-size: 28px; font-weight: bold; color: #c9a227; }
        .stat-label { font-size: 14px; color: #888; }
        table { width: 100%; border-collapse: collapse; background: #0e1528; }
        th { text-align: right; padding: 15px; color: #c9a227; border-bottom: 2px solid #111a30; }
        td { padding: 15px; border-bottom: 1px solid #111a30; font-size: 14px; }
        .code-text { font-family: monospace; background: #111a30; padding: 4px 8px; border-radius: 4px; color: #c9a227; }
        .btn { padding: 8px 16px; border-radius: 6px; border: none; cursor: pointer; font-weight: bold; transition: 0.3s; font-size: 13px; text-decoration: none; display: inline-block; }
        .btn-primary { background: #c9a227; color: #070b18; }
        .btn-danger { background: #ff475722; color: #ff4757; border: 1px solid #ff475744; }
        .btn-info { background: #2f3542; color: #70a1ff; border: 1px solid #70a1ff44; }
        .badge { padding: 4px 8px; border-radius: 4px; font-size: 11px; }
        .badge-success { background: #2ed57322; color: #2ed573; }
        .badge-warning { background: #ffa50222; color: #ffa502; }
    </style>
    <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;700&display=swap" rel="stylesheet">
</head>
<body>
    <div class="sidebar">
        <div class="logo">WLLFox Panel</div>
        <a href="./" class="nav-item active">لوحة التحكم</a>
        <a href="#" class="nav-item">الإعدادات</a>
        <a href="?logout" class="nav-item" style="margin-top: 50px; color: #ff4757;">تسجيل الخروج</a>
    </div>

    <div class="main-content">
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value"><?php echo count($db['codes']); ?></div>
                <div class="stat-label">إجمالي الأكواد</div>
            </div>
            <div class="stat-card">
                <?php 
                    $used = 0;
                    foreach($db['codes'] as $c) if(!empty($c['udid'])) $used++;
                ?>
                <div class="stat-value"><?php echo $used; ?></div>
                <div class="stat-label">أجهزة مفعلة</div>
            </div>
        </div>

        <div class="card">
            <h3 style="margin-top:0; color:#c9a227;">توليد أكواد جديدة</h3>
            <form method="POST" style="display:flex; gap:15px; align-items:center;">
                <select name="days" style="padding:10px; background:#111a30; border:1px solid #c9a22733; color:white; border-radius:8px;">
                    <option value="7">7 أيام</option>
                    <option value="30" selected>30 يوم</option>
                    <option value="90">90 يوم</option>
                    <option value="365">سنة كاملة</option>
                </select>
                <button type="submit" name="add_code" class="btn btn-primary">توليد كود تفعيل</button>
            </form>
        </div>

        <div class="card" style="padding:0; overflow:hidden;">
            <table>
                <thead>
                    <tr>
                        <th>كود التفعيل</th>
                        <th>الحالة</th>
                        <th>الجهاز المرتبط (UDID)</th>
                        <th>تاريخ الانتهاء</th>
                        <th>الإجراءات</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach(array_reverse($db['codes'], true) as $code => $data): ?>
                    <tr>
                        <td><span class="code-text"><?php echo $code; ?></span></td>
                        <td>
                            <?php if(empty($data['udid'])): ?>
                                <span class="badge badge-success">جاهز للاستخدام</span>
                            <?php else: ?>
                                <span class="badge badge-warning">مستخدم</span>
                            <?php endif; ?>
                        </td>
                        <td style="font-size:11px; color:#888;"><?php echo $data['udid'] ?: '---'; ?></td>
                        <td><?php echo $data['expiry']; ?></td>
                        <td>
                            <a href="?reset=<?php echo $code; ?>" class="btn btn-info">إعادة ضبط</a>
                            <a href="?delete=<?php echo $code; ?>" class="btn btn-danger" onclick="return confirm('حذف الكود نهائياً؟')">حذف</a>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
