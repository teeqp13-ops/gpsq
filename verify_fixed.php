<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

$code = isset($_GET['code']) ? trim($_GET['code']) : '';
$udid = isset($_GET['udid']) ? trim($_GET['udid']) : '';

$dbFile = 'database.json';
if (!file_exists($dbFile)) {
    file_put_contents($dbFile, json_encode(['codes' => []]));
}

$db = json_decode(file_get_contents($dbFile), true);

if (!isset($db['codes'][$code])) {
    echo json_encode(['status' => 'error', 'message' => 'كود التفعيل غير موجود']);
    exit;
}

$codeData = $db['codes'][$code];

// التحقق من ربط الجهاز
if (!empty($codeData['udid']) && $codeData['udid'] !== $udid) {
    echo json_encode(['status' => 'error', 'message' => 'هذا الكود مفعل على جهاز آخر']);
    exit;
}

// ربط الجهاز إذا كان أول استخدام
if (empty($codeData['udid'])) {
    $db['codes'][$code]['udid'] = $udid;
    file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
}

echo json_encode(['status' => 'success', 'message' => 'تم التفعيل بنجاح']);
?>
