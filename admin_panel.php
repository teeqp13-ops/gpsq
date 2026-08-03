<?php
/**
 * WLLFox GPS - Admin Dashboard
 * Copyright (c) 2026 LaylaStore
 */

session_start();
$admin_pass = "admin123"; // قم بتغيير كلمة المرور هنا
$dbFile = 'database.json';

if (!file_exists($dbFile)) {
    file_put_contents($dbFile, json_encode(['codes' => []]));
}
$db = json_decode(file_get_contents($dbFile), true);

// تسجيل الخروج
if (isset($_GET['logout'])) {
    session_destroy();
    header("Location: admin_panel.php");
    exit;
}

// التحقق من تسجيل الدخول
if (!isset($_SESSION['logged_in'])) {
    if (isset($_POST['pass']) && $_POST['pass'] === $admin_pass) {
        $_SESSION['logged_in'] = true;
    } else {
        die('
        <body style="background:#070b18;color:white;display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;">
            <form method="POST" style="background:#0e1528;padding:30px;border-radius:15px;border:1px solid #c9a227;">
                <h2 style="color:#c9a227;text-align:center;">WLLFox Admin</h2>
                <input type="password" name="pass" placeholder="كلمة المرور" style="width:100%;padding:10px;margin:10px 0;background:#111a30;border:1px solid #c9a227;color:white;">
                <button type="submit" style="width:104%;padding:10px;background:#c9a227;border:none;color:#070b18;font-weight:bold;cursor:pointer;">دخول</button>
            </form>
        </body>');
    }
}

// إضافة كود جديد
if (isset($_POST['add_code'])) {
    $code = strtoupper(substr(md5(time().rand()), 0, 12));
    $db['codes'][$code] = [
        'udid' => '',
        'expiry' => date('Y-m-d', strtotime('+30 days')),
        'status' => 'active',
        'created_at' => date('Y-m-d H:i:s')
    ];
    file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
}

// حذف كود
if (isset($_GET['delete'])) {
    unset($db['codes'][$_GET['delete']]);
    file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
    header("Location: admin_panel.php");
}

// إعادة ضبط UDID
if (isset($_GET['reset'])) {
    $db['codes'][$_GET['reset']]['udid'] = '';
    file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
    header("Location: admin_panel.php");
}

?>
<!DOCTYPE html>
<html dir="rtl">
<head>
    <title>WLLFox GPS - لوحة التحكم</title>
    <style>
        body { background: #070b18; color: white; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; padding: 20px; }
        .container { max-width: 1000px; margin: auto; }
        .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #c9a227; padding-bottom: 10px; }
        .card { background: #0e1528; padding: 20px; border-radius: 15px; margin-top: 20px; border: 1px solid #c9a22733; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; text-align: right; border-bottom: 1px solid #111a30; }
        th { color: #c9a227; }
        .btn { padding: 8px 15px; border-radius: 5px; text-decoration: none; font-size: 14px; cursor: pointer; border: none; }
        .btn-add { background: #c9a227; color: #070b18; font-weight: bold; }
        .btn-reset { background: #2e86de; color: white; }
        .btn-del { background: #ee5253; color: white; }
        .status-active { color: #1dd1a1; }
        .status-used { color: #feca57; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>WLLFox GPS Dashboard</h1>
            <a href="?logout" style="color:#ee5253;">تسجيل الخروج</a>
        </div>

        <div class="card">
            <form method="POST">
                <button type="submit" name="add_code" class="btn btn-add">+ توليد كود جديد (30 يوم)</button>
            </form>
            
            <table>
                <thead>
                    <tr>
                        <th>الكود</th>
                        <th>الحالة</th>
                        <th>الجهاز (UDID)</th>
                        <th>تاريخ الانتهاء</th>
                        <th>الإجراءات</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach($db['codes'] as $code => $data): ?>
                    <tr>
                        <td style="font-family:monospace;"><?php echo $code; ?></td>
                        <td>
                            <span class="<?php echo empty($data['udid']) ? 'status-active' : 'status-used'; ?>">
                                <?php echo empty($data['udid']) ? 'جاهز' : 'مستخدم'; ?>
                            </span>
                        </td>
                        <td style="font-size:10px;"><?php echo $data['udid'] ?: '---'; ?></td>
                        <td><?php echo $data['expiry']; ?></td>
                        <td>
                            <a href="?reset=<?php echo $code; ?>" class="btn btn-reset">إعادة ضبط الجهاز</a>
                            <a href="?delete=<?php echo $code; ?>" class="btn btn-del" onclick="return confirm('هل أنت متأكد؟')">حذف</a>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
