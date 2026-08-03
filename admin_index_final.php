<?php
/**
 * WLLFox GPS Pro - Professional Admin Dashboard
 * Fixed Code Generation & Design
 */

session_start();
$admin_pass = "admin123"; 
$dbFile = '../api/database.json';

// إعداد قاعدة البيانات والتأكد من الصلاحيات
if (!file_exists('../api')) mkdir('../api', 0777, true);
if (!file_exists($dbFile)) {
    file_put_contents($dbFile, json_encode(['projects' => ['WLLFox GPS Pro'], 'codes' => []], JSON_PRETTY_PRINT));
}

$db = json_decode(file_get_contents($dbFile), true);
$error = "";
$success = "";

// منطق تسجيل الدخول
if (!isset($_SESSION['logged_in'])) {
    if (isset($_POST['pass']) && $_POST['pass'] === $admin_pass) {
        $_SESSION['logged_in'] = true;
    } else {
        die('
        <body style="background:#070b18;color:white;display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;margin:0;">
            <form method="POST" style="background:#0e1528;padding:40px;border-radius:20px;border:1px solid #c9a227;width:320px;text-align:center;box-shadow:0 10px 30px rgba(0,0,0,0.5);">
                <h2 style="color:#c9a227;margin-bottom:30px;">WLLFox Admin</h2>
                <input type="password" name="pass" placeholder="كلمة المرور" style="width:100%;padding:12px;margin-bottom:20px;background:#111a30;border:1px solid #c9a22733;border-radius:8px;color:white;outline:none;box-sizing:border-box;">
                <button type="submit" style="width:100%;padding:12px;background:#c9a227;border:none;border-radius:8px;color:#070b18;font-weight:bold;cursor:pointer;transition:0.3s;">دخول النظام</button>
            </form>
        </body>');
    }
}

// منطق توليد الأكواد المصلح
if (isset($_POST['add_code'])) {
    $newCode = "WLF-" . strtoupper(substr(md5(time().rand()), 0, 4) . "-" . substr(md5(time().rand()), 4, 4));
    $db['codes'][$newCode] = [
        'project' => 'WLLFox GPS Pro',
        'udid' => '',
        'status' => 'active',
        'expiry' => date('Y-m-d', strtotime('+30 days')),
        'created_at' => date('Y-m-d H:i:s')
    ];
    if (file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT))) {
        $success = "تم توليد الكود: $newCode";
    } else {
        $error = "فشل في الحفظ! تأكد من صلاحيات المجلد (chmod 777)";
    }
}

// حذف وإعادة ضبط
if (isset($_GET['reset'])) {
    $db['codes'][$_GET['reset']]['udid'] = '';
    file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
    header("Location: ./"); exit;
}
if (isset($_GET['delete'])) {
    unset($db['codes'][$_GET['delete']]);
    file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
    header("Location: ./"); exit;
}
?>
<!DOCTYPE html>
<html dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>إدارة الأكواد - WLLFox</title>
    <style>
        body { background:#070b18; color:#e1e1e1; font-family:sans-serif; margin:0; padding:20px; }
        .container { max-width: 900px; margin: auto; }
        .header { text-align:center; margin-bottom:30px; }
        .header h1 { color:#c9a227; margin:0; font-size:28px; }
        .card { background:#0e1528; border-radius:15px; padding:20px; border:1px solid #c9a22722; margin-bottom:20px; box-shadow:0 4px 15px rgba(0,0,0,0.3); }
        .btn-gen { background: linear-gradient(90deg, #6a11cb 0%, #2575fc 100%); color:white; width:100%; padding:15px; border-radius:10px; border:none; font-size:18px; font-weight:bold; cursor:pointer; margin-bottom:10px; transition:0.3s; }
        .btn-gen:hover { opacity:0.9; transform:scale(0.99); }
        .search-box { width:100%; padding:12px; background:#111a30; border:1px solid #c9a22733; border-radius:8px; color:white; margin-bottom:15px; box-sizing:border-box; }
        table { width:100%; border-collapse:collapse; margin-top:10px; }
        th { text-align:right; color:#c9a227; padding:12px; border-bottom:2px solid #111a30; font-size:14px; }
        td { padding:12px; border-bottom:1px solid #111a30; font-size:13px; }
        .code-tag { background:#111a30; padding:5px 10px; border-radius:5px; border:1px solid #c9a22744; color:#c9a227; font-family:monospace; }
        .status-badge { padding:3px 8px; border-radius:4px; font-size:11px; }
        .bg-green { background:rgba(46,213,115,0.2); color:#2ed573; }
        .bg-orange { background:rgba(255,165,2,0.2); color:#ffa502; }
        .action-link { text-decoration:none; font-size:12px; margin-left:10px; transition:0.2s; }
        .copy-btn { background:#c9a22722; color:#c9a227; padding:2px 6px; border-radius:4px; cursor:pointer; font-size:10px; margin-right:5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>إدارة الأكواد</h1>
            <p style="color:#888;"><?php echo date('H:i Y-m-d'); ?></p>
        </div>

        <?php if($error): ?> <div style="background:#ff475722; color:#ff4757; padding:15px; border-radius:8px; margin-bottom:20px; border:1px solid #ff4757;"><?php echo $error; ?></div> <?php endif; ?>
        <?php if($success): ?> <div style="background:#2ed57322; color:#2ed573; padding:15px; border-radius:8px; margin-bottom:20px; border:1px solid #2ed573;"><?php echo $success; ?></div> <?php endif; ?>

        <div class="card">
            <form method="POST">
                <button type="submit" name="add_code" class="btn-gen">+ توليد أكواد</button>
            </form>
        </div>

        <div class="card" style="padding:0; overflow:hidden;">
            <div style="padding:15px;">
                <input type="text" class="search-box" placeholder="بحث بالكود...">
            </div>
            <table>
                <thead>
                    <tr>
                        <th>الكود</th>
                        <th>المشروع</th>
                        <th>الحالة</th>
                        <th>الإجراءات</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach(array_reverse($db['codes'], true) as $code => $data): ?>
                    <tr>
                        <td>
                            <span class="code-tag"><?php echo $code; ?></span>
                        </td>
                        <td>WLLFox GPS Pro</td>
                        <td>
                            <?php if(empty($data['udid'])): ?>
                                <span class="status-badge bg-green">جاهز</span>
                            <?php else: ?>
                                <span class="status-badge bg-orange">مستخدم</span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <a href="?reset=<?php echo $code; ?>" class="action-link" style="color:#4facfe;">إعادة ضبط</a>
                            <a href="?delete=<?php echo $code; ?>" class="action-link" style="color:#ff4757;" onclick="return confirm('حذف؟')">حذف</a>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
