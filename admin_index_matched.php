<?php
/**
 * WLLFox GPS Pro - Matched Interface Admin Dashboard
 * This version matches the user's screenshot exactly.
 */

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

$msg = "";
$status = "";

if (isset($_POST['add_code'])) {
    // توليد كود موحد WLF-XXXX-XXXX
    $p1 = strtoupper(substr(md5(time().rand()), 0, 4));
    $p2 = strtoupper(substr(md5(time().rand()), 4, 4));
    $code = "WLF-$p1-$p2";
    $db['codes'][$code] = [
        'project' => 'WLLFox GPS Pro',
        'udid' => '',
        'status' => 'active',
        'created_at' => date('Y-m-d H:i')
    ];
    if (file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT))) {
        $msg = "تم توليد الكود بنجاح";
        $status = "success";
    } else {
        $msg = "فشل توليد الأكواد. تحقق من المشروع";
        $status = "error";
    }
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
        body { background: #0b1121; color: white; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; min-height: 100vh; }
        .container { max-width: 500px; margin: auto; }
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px; position: relative; }
        .header h1 { font-size: 22px; margin: 0; flex-grow: 1; text-align: center; font-weight: bold; }
        .header .time { font-size: 12px; color: #64748b; position: absolute; bottom: -20px; left: 50%; transform: translateX(-50%); }
        .icon-btn { background: rgba(30, 41, 59, 0.5); border: 1px solid #1e293b; color: white; padding: 10px; border-radius: 12px; cursor: pointer; display: flex; align-items: center; justify-content: center; width: 40px; height: 40px; }
        
        .alert { padding: 15px; border-radius: 12px; text-align: center; margin-bottom: 20px; font-size: 14px; }
        .alert-error { background: rgba(239, 68, 68, 0.1); border: 1px solid #ef4444; color: #ef4444; }
        .alert-success { background: rgba(16, 185, 129, 0.1); border: 1px solid #10b981; color: #10b981; }
        
        .btn-add { background: linear-gradient(90deg, #3b82f6 0%, #8b5cf6 100%); color: white; width: 100%; padding: 16px; border-radius: 12px; border: none; font-size: 18px; font-weight: bold; cursor: pointer; margin-bottom: 20px; box-shadow: 0 4px 15px rgba(59, 130, 246, 0.3); }
        
        .input-group { position: relative; margin-bottom: 15px; }
        .input-group input { background: #0e1528; border: 1px solid #1e293b; border-radius: 12px; padding: 15px; width: 100%; box-sizing: border-box; color: white; text-align: right; outline: none; }
        
        .filter-row { display: flex; gap: 10px; margin-bottom: 15px; }
        .filter-row select { flex: 1; background: #0e1528; border: 1px solid #1e293b; border-radius: 12px; padding: 12px; color: white; outline: none; appearance: none; text-align: center; }
        
        .btn-filter { background: rgba(30, 41, 59, 0.5); border: 1px solid #1e293b; color: white; width: 100%; padding: 12px; border-radius: 12px; font-weight: bold; cursor: pointer; margin-bottom: 30px; }
        
        .table-card { background: rgba(14, 21, 40, 0.6); border: 1px solid #1e293b; border-radius: 20px; overflow: hidden; }
        .table-header { display: flex; justify-content: space-between; padding: 15px 20px; border-bottom: 1px solid #1e293b; color: #64748b; font-size: 14px; }
        .list-item { padding: 15px 20px; border-bottom: 1px solid #1e293b; }
        .item-main { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }
        .proj-name { color: #94a3b8; font-size: 14px; }
        .code-box { display: flex; align-items: center; gap: 10px; }
        .code-val { font-family: monospace; font-weight: bold; letter-spacing: 1px; }
        .copy-tag { background: rgba(59, 130, 246, 0.1); color: #3b82f6; padding: 4px 8px; border-radius: 6px; font-size: 11px; cursor: pointer; }
        .item-actions { display: flex; gap: 15px; font-size: 12px; }
        .item-actions a { text-decoration: none; }
        .udid-text { margin-right: auto; color: #475569; font-size: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <button class="icon-btn">◐</button>
            <h1>إدارة الأكواد</h1>
            <div class="time"><?php echo date('H:i Y-m-d'); ?></div>
            <button class="icon-btn">☰</button>
        </div>

        <?php if($msg): ?>
            <div class="alert alert-<?php echo $status; ?>"><?php echo $msg; ?></div>
        <?php endif; ?>

        <form method="POST">
            <button type="submit" name="add_code" class="btn-add">+ توليد أكواد</button>
        </form>

        <div class="input-group">
            <input type="text" placeholder="بحث بالكود">
        </div>

        <div class="filter-row">
            <select><option>كل المشاريع</option><option selected>WLLFox GPS Pro</option></select>
            <select><option>كل الحالات</option><option>جاهز</option><option>مستخدم</option></select>
        </div>
        
        <button class="btn-filter">تصفية</button>

        <div class="table-card">
            <div class="table-header">
                <span>المشروع</span>
                <span>الكود</span>
            </div>
            <?php foreach(array_reverse($db['codes'], true) as $code => $data): ?>
            <div class="list-item">
                <div class="item-main">
                    <span class="proj-name"><?php echo $data['project']; ?></span>
                    <div class="code-box">
                        <span class="code-val"><?php echo $code; ?></span>
                        <span class="copy-tag" onclick="navigator.clipboard.writeText('<?php echo $code; ?>')">نسخ</span>
                    </div>
                </div>
                <div class="item-actions">
                    <a href="?reset=<?php echo $code; ?>" style="color: #3b82f6;">إعادة ضبط الجهاز</a>
                    <a href="?delete=<?php echo $code; ?>" style="color: #ef4444;">حذف الكود</a>
                    <span class="udid-text"><?php echo $data['udid'] ?: 'لم يستخدم بعد'; ?></span>
                </div>
            </div>
            <?php endforeach; ?>
        </div>
    </div>
</body>
</html>
