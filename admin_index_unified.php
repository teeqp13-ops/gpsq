<?php
session_start();
$admin_pass = "admin123";
$dbFile = '../api/database.json';
if (!file_exists('../api')) mkdir('../api', 0777, true);
if (!file_exists($dbFile)) file_put_contents($dbFile, json_encode(['codes' => []]));
$db = json_decode(file_get_contents($dbFile), true);

if (!isset($_SESSION['logged_in'])) {
    if (isset($_POST['pass']) && $_POST['pass'] === $admin_pass) $_SESSION['logged_in'] = true;
    else die('<body style="background:#070b18;color:white;display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;margin:0;"><form method="POST" style="background:#0e1528;padding:40px;border-radius:20px;border:1px solid #c9a227;width:300px;text-align:center;"><h2 style="color:#c9a227;">WLLFox Admin</h2><input type="password" name="pass" placeholder="كلمة المرور" style="width:100%;padding:12px;margin:20px 0;background:#111a30;border:1px solid #c9a22733;border-radius:8px;color:white;outline:none;"><button type="submit" style="width:100%;padding:12px;background:#c9a227;border:none;border-radius:8px;color:#070b18;font-weight:bold;cursor:pointer;">دخول</button></form></body>');
}

if (isset($_POST['add_code'])) {
    // نمط موحد للأكواد: WLF-XXXX-XXXX
    $p1 = strtoupper(substr(md5(time().rand()), 0, 4));
    $p2 = strtoupper(substr(md5(time().rand()), 4, 4));
    $code = "WLF-$p1-$p2";
    $db['codes'][$code] = ['udid' => '', 'expiry' => date('Y-m-d', strtotime('+30 days'))];
    file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
}

if (isset($_GET['reset'])) { $db['codes'][$_GET['reset']]['udid'] = ''; file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT)); header("Location: ./"); exit; }
if (isset($_GET['delete'])) { unset($db['codes'][$_GET['delete']]); file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT)); header("Location: ./"); exit; }
?>
<!DOCTYPE html>
<html dir="rtl">
<head>
    <meta charset="UTF-8">
    <title>WLLFox GPS Pro - إدارة الأكواد الموحدة</title>
    <style>
        body { background:#070b18; color:#e1e1e1; font-family:sans-serif; margin:0; padding:20px; }
        .container { max-width: 900px; margin: auto; }
        .card { background:#0e1528; border-radius:15px; padding:25px; border:1px solid #c9a22733; margin-bottom:20px; box-shadow: 0 10px 30px rgba(0,0,0,0.3); }
        .btn-gen { background: linear-gradient(135deg, #c9a227 0%, #a6841d 100%); color:#070b18; width:100%; padding:18px; border-radius:12px; border:none; font-size:20px; font-weight:bold; cursor:pointer; transition: 0.3s; }
        .btn-gen:hover { transform: translateY(-2px); box-shadow: 0 5px 15px rgba(201,162,39,0.4); }
        table { width:100%; border-collapse:collapse; margin-top:20px; }
        th { text-align:right; color:#c9a227; padding:15px; border-bottom:2px solid #111a30; font-size:15px; }
        td { padding:15px; border-bottom:1px solid #111a30; font-size:14px; }
        .code-tag { background:#111a30; padding:8px 12px; border-radius:6px; border:1px solid #c9a22755; color:#c9a227; font-family:monospace; font-weight:bold; letter-spacing:1px; }
        .status { padding:4px 10px; border-radius:6px; font-size:12px; font-weight:bold; }
        .ready { background:rgba(46,213,115,0.15); color:#2ed573; }
        .used { background:rgba(255,165,2,0.15); color:#ffa502; }
        .action-btn { text-decoration:none; padding:5px 10px; border-radius:5px; font-size:12px; transition:0.2s; }
    </style>
</head>
<body>
    <div class="container">
        <h1 style="text-align:center; color:#c9a227; font-size:32px; margin-bottom:40px;">نظام إدارة الأكواد الموحد</h1>
        <div class="card">
            <form method="POST"><button type="submit" name="add_code" class="btn-gen">+ توليد كود WLF موحد</button></form>
        </div>
        <div class="card" style="padding:0; overflow:hidden;">
            <table>
                <thead>
                    <tr>
                        <th>كود التفعيل</th>
                        <th>الحالة</th>
                        <th>الجهاز (UDID)</th>
                        <th>الإجراءات</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach(array_reverse($db['codes'], true) as $code => $data): ?>
                    <tr>
                        <td><span class="code-tag"><?php echo $code; ?></span></td>
                        <td><?php echo empty($data['udid']) ? '<span class="status ready">جاهز</span>' : '<span class="status used">مستخدم</span>'; ?></td>
                        <td style="font-size:10px; color:#888;"><?php echo $data['udid'] ?: '---'; ?></td>
                        <td>
                            <a href="?reset=<?php echo $code; ?>" class="action-btn" style="color:#4facfe; background:rgba(79,172,254,0.1);">إعادة ضبط</a>
                            <a href="?delete=<?php echo $code; ?>" class="action-btn" style="color:#ff4757; background:rgba(255,71,87,0.1); margin-right:10px;" onclick="return confirm('حذف؟')">حذف</a>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
