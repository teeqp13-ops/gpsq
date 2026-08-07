<?php
/**
 * WLLFox GPS Pro - Fixed Admin Dashboard
 */

session_start();
$admin_pass = "admin123"; 
$dbFile = '../api/database.json';

// إعداد قاعدة البيانات الأولية
if (!file_exists('../api')) mkdir('../api', 0777, true);
if (!file_exists($dbFile)) {
    file_put_contents($dbFile, json_encode([
        'projects' => ['WLLFox GPS Pro'],
        'codes' => []
    ], JSON_PRETTY_PRINT));
}

$db = json_decode(file_get_contents($dbFile), true);

// التأكد من وجود المشروع في القائمة لتجنب خطأ "تحقق من المشروع"
if (!isset($db['projects']) || !in_array('WLLFox GPS Pro', $db['projects'])) {
    $db['projects'][] = 'WLLFox GPS Pro';
    file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
}

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
            <form method="POST" style="background:#0e1528;padding:40px;border-radius:20px;border:1px solid #c9a227;width:300px;text-align:center;">
                <h2 style="color:#c9a227;">WLLFox Admin</h2>
                <input type="password" name="pass" placeholder="كلمة المرور" style="width:100%;padding:12px;margin:20px 0;background:#111a30;border:1px solid #c9a22733;border-radius:8px;color:white;outline:none;">
                <button type="submit" style="width:100%;padding:12px;background:#c9a227;border:none;border-radius:8px;color:#070b18;font-weight:bold;cursor:pointer;">دخول</button>
            </form>
        </body>');
    }
}

$error = "";
$success = "";

// إضافة كود جديد
if (isset($_POST['add_code'])) {
    try {
        $code = "WLF-" . strtoupper(substr(md5(time().rand()), 0, 8));
        $db['codes'][$code] = [
            'project' => 'WLLFox GPS Pro',
            'udid' => '',
            'expiry' => date('Y-m-d', strtotime('+30 days')),
            'created_at' => date('Y-m-d H:i:s')
        ];
        if (file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT))) {
            $success = "تم توليد الكود بنجاح: $code";
        } else {
            $error = "فشل الكتابة في ملف قاعدة البيانات. تأكد من الصلاحيات (chmod 777).";
        }
    } catch (Exception $e) {
        $error = "خطأ: " . $e->getMessage();
    }
}

// الإجراءات الأخرى (حذف، إعادة ضبط)
if (isset($_GET['reset'])) {
    $db['codes'][$_GET['reset']]['udid'] = '';
    file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
    header("Location: ./");
}
if (isset($_GET['delete'])) {
    unset($db['codes'][$_GET['delete']]);
    file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
    header("Location: ./");
}

?>
<!DOCTYPE html>
<html dir="rtl">
<head>
    <meta charset="UTF-8">
    <title>WLLFox GPS Pro - الإدارة</title>
    <style>
        body { background: #070b18; color: #e1e1e1; font-family: sans-serif; margin: 0; padding: 20px; }
        .container { max-width: 900px; margin: auto; }
        .card { background: #0e1528; border-radius: 15px; padding: 20px; border: 1px solid #c9a22722; margin-bottom: 20px; }
        .btn { padding: 10px 20px; border-radius: 8px; border: none; cursor: pointer; font-weight: bold; text-decoration: none; display: inline-block; }
        .btn-main { background: linear-gradient(90deg, #4facfe 0%, #00f2fe 100%); color: white; width: 100%; font-size: 18px; }
        .alert { padding: 15px; border-radius: 8px; margin-bottom: 20px; }
        .alert-error { background: rgba(255, 71, 87, 0.1); border: 1px solid #ff4757; color: #ff4757; }
        .alert-success { background: rgba(46, 213, 115, 0.1); border: 1px solid #2ed573; color: #2ed573; }
        table { width: 100%; border-collapse: collapse; }
        th { text-align: right; color: #c9a227; padding: 10px; border-bottom: 1px solid #c9a22722; }
        td { padding: 10px; border-bottom: 1px solid #111a30; font-size: 14px; }
        .code-box { font-family: monospace; background: #111a30; padding: 5px; border-radius: 4px; color: #c9a227; }
    </style>
</head>
<body>
    <div class="container">
        <h1 style="text-align:center; color:#c9a227;">إدارة الأكواد</h1>
        <p style="text-align:center;"><?php echo date('H:i Y-m-d'); ?></p>

        <?php if($error): ?> <div class="alert alert-error"><?php echo $error; ?></div> <?php endif; ?>
        <?php if($success): ?> <div class="alert alert-success"><?php echo $success; ?></div> <?php endif; ?>

        <div class="card">
            <form method="POST">
                <button type="submit" name="add_code" class="btn btn-main">+ توليد أكواد</button>
            </form>
        </div>

        <div class="card">
            <table>
                <thead>
                    <tr>
                        <th>الكود</th>
                        <th>المشروع</th>
                        <th>الجهاز</th>
                        <th>الإجراءات</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach(array_reverse($db['codes'], true) as $c => $d): ?>
                    <tr>
                        <td><span class="code-box"><?php echo $c; ?></span></td>
                        <td><?php echo $d['project']; ?></td>
                        <td style="font-size:10px;"><?php echo $d['udid'] ?: '---'; ?></td>
                        <td>
                            <a href="?reset=<?php echo $c; ?>" style="color:#4facfe;">إعادة ضبط</a> | 
                            <a href="?delete=<?php echo $c; ?>" style="color:#ff4757;">حذف</a>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
