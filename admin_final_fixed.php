<?php
/**
 * WLLFox GPS Pro - Final Professional Dashboard
 * Matches User Design & Fixes Generation
 */

session_start();
$admin_pass = "admin123";
$dbFile = '../api/database.json';

if (!file_exists('../api')) mkdir('../api', 0777, true);
if (!file_exists($dbFile)) {
    file_put_contents($dbFile, json_encode(['codes' => []], JSON_PRETTY_PRINT));
}

$db = json_decode(file_get_contents($dbFile), true);

if (!isset($_SESSION['logged_in'])) {
    if (isset($_POST['pass']) && $_POST['pass'] === $admin_pass) $_SESSION['logged_in'] = true;
    else die('<body style="background:#070b18;color:white;display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;margin:0;"><form method="POST" style="background:#0e1528;padding:40px;border-radius:20px;border:1px solid #c9a227;width:300px;text-align:center;"><h2 style="color:#c9a227;">WLLFox Admin</h2><input type="password" name="pass" placeholder="كلمة المرور" style="width:100%;padding:12px;margin:20px 0;background:#111a30;border:1px solid #c9a22733;border-radius:8px;color:white;outline:none;"><button type="submit" style="width:100%;padding:12px;background:#c9a227;border:none;border-radius:8px;color:#070b18;font-weight:bold;cursor:pointer;">دخول</button></form></body>');
}

$success_msg = "";
if (isset($_POST['add_code'])) {
    $p1 = strtoupper(substr(md5(time().rand()), 0, 4));
    $p2 = strtoupper(substr(md5(time().rand()), 4, 4));
    $newCode = "WLF-$p1-$p2";
    $db['codes'][$newCode] = [
        'project' => 'WLLFox GPS Pro',
        'udid' => '',
        'created_at' => date('Y-m-d H:i')
    ];
    file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
    $success_msg = "تم توليد الكود بنجاح";
}

if (isset($_GET['reset'])) { $db['codes'][$_GET['reset']]['udid'] = ''; file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT)); header("Location: ./"); exit; }
if (isset($_GET['delete'])) { unset($db['codes'][$_GET['delete']]); file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT)); header("Location: ./"); exit; }

?>
<!DOCTYPE html>
<html dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>إدارة الأكواد</title>
    <style>
        body { background: radial-gradient(circle at top, #0f172a 0%, #070b18 100%); color: white; font-family: 'Segoe UI', sans-serif; margin: 0; padding: 20px; min-height: 100vh; }
        .container { max-width: 500px; margin: auto; }
        .header { text-align: center; margin-bottom: 30px; position: relative; }
        .header h1 { font-size: 24px; margin-bottom: 5px; }
        .header p { font-size: 14px; color: #888; margin: 0; }
        .menu-btn { position: absolute; right: 0; top: 10px; background: #0e1528; border: 1px solid #1e293b; padding: 8px; border-radius: 8px; color: white; cursor: pointer; }
        .theme-btn { position: absolute; left: 0; top: 10px; background: #0e1528; border: 1px solid #1e293b; padding: 8px; border-radius: 50%; color: white; cursor: pointer; }
        
        .alert-success { background: rgba(16, 185, 129, 0.1); border: 1px solid #10b981; color: #10b981; padding: 15px; border-radius: 12px; text-align: center; margin-bottom: 20px; }
        
        .btn-add { background: linear-gradient(90deg, #3b82f6 0%, #8b5cf6 100%); color: white; width: 100%; padding: 16px; border-radius: 12px; border: none; font-size: 18px; font-weight: bold; cursor: pointer; margin-bottom: 20px; box-shadow: 0 4px 15px rgba(59, 130, 246, 0.3); transition: 0.3s; }
        .btn-add:active { transform: scale(0.98); }
        
        .search-box { background: #0e1528; border: 1px solid #1e293b; border-radius: 12px; padding: 15px; width: 100%; box-sizing: border-box; color: white; margin-bottom: 15px; outline: none; text-align: right; }
        
        .filter-row { display: flex; gap: 10px; margin-bottom: 20px; }
        .filter-row select, .filter-row button { flex: 1; background: #0e1528; border: 1px solid #1e293b; border-radius: 12px; padding: 12px; color: white; outline: none; cursor: pointer; }
        
        .code-list { background: #0e1528; border: 1px solid #1e293b; border-radius: 15px; overflow: hidden; }
        .list-header { display: flex; justify-content: space-between; padding: 15px; border-bottom: 1px solid #1e293b; color: #888; font-size: 14px; }
        .list-item { display: flex; justify-content: space-between; align-items: center; padding: 15px; border-bottom: 1px solid #1e293b; }
        .project-name { font-size: 14px; color: #e1e1e1; }
        .code-val { font-family: monospace; color: white; font-weight: bold; }
        .copy-btn { background: #1e293b; color: #3b82f6; border: none; padding: 6px 12px; border-radius: 6px; font-size: 12px; cursor: pointer; }
        .action-btns { display: flex; gap: 10px; margin-top: 10px; padding: 0 15px 15px; }
        .action-btns a { font-size: 12px; text-decoration: none; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <button class="theme-btn">◐</button>
            <h1>إدارة الأكواد</h1>
            <p><?php echo date('H:i Y-m-d'); ?></p>
            <button class="menu-btn">☰</button>
        </div>

        <?php if($success_msg): ?> <div class="alert-success"><?php echo $success_msg; ?></div> <?php endif; ?>

        <form method="POST">
            <button type="submit" name="add_code" class="btn-add">+ توليد أكواد</button>
        </form>

        <input type="text" class="search-box" placeholder="بحث بالكود">

        <div class="filter-row">
            <select><option>كل المشاريع</option><option selected>WLLFox GPS Pro</option></select>
            <select><option>كل الحالات</option><option>جاهز</option><option>مستخدم</option></select>
        </div>
        
        <button class="filter-row" style="width:100%; background:#0e1528; border:1px solid #1e293b; color:white; padding:12px; border-radius:12px; margin-bottom:20px; font-weight:bold;">تصفية</button>

        <div class="code-list">
            <div class="list-header">
                <span>المشروع</span>
                <span>الكود</span>
            </div>
            <?php foreach(array_reverse($db['codes'], true) as $code => $data): ?>
            <div class="list-item">
                <span class="project-name"><?php echo $d['project'] ?? 'WLLFox GPS Pro'; ?></span>
                <div style="display:flex; align-items:center; gap:10px;">
                    <span class="code-val"><?php echo $code; ?></span>
                    <button class="copy-btn" onclick="navigator.clipboard.writeText('<?php echo $code; ?>')">نسخ</button>
                </div>
            </div>
            <div class="action-btns">
                <a href="?reset=<?php echo $code; ?>" style="color:#3b82f6;">إعادة ضبط الجهاز</a>
                <a href="?delete=<?php echo $code; ?>" style="color:#ef4444;">حذف الكود</a>
                <span style="margin-right:auto; color:#555; font-size:10px;"><?php echo $data['udid'] ?: 'لم يستخدم'; ?></span>
            </div>
            <?php endforeach; ?>
        </div>
    </div>
</body>
</html>
