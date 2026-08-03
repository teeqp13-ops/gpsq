<?php
/**
 * WLLFox GPS - Smart Activation System
 * Copyright (c) 2026 LaylaStore
 */

header('Content-Type: application/json; charset=utf-8');

// إعدادات الأمان
$ALLOWED_USER_AGENT = "WLLFox-Tweak-Client";
if ($_SERVER['HTTP_USER_AGENT'] !== $ALLOWED_USER_AGENT) {
    die(json_encode(['status' => 'error', 'message' => 'Access Denied']));
}

$code = isset($_GET['code']) ? trim($_GET['code']) : '';
$udid = isset($_GET['udid']) ? trim($_GET['udid']) : '';
$proj = isset($_GET['proj']) ? trim($_GET['proj']) : '';

if (empty($code) || empty($udid)) {
    echo json_encode(['status' => 'error', 'message' => 'بيانات ناقصة']);
    exit;
}

// ملف قاعدة البيانات البسيط (JSON)
$dbFile = 'database.json';
if (!file_exists($dbFile)) {
    file_put_contents($dbFile, json_encode(['codes' => [], 'logs' => []]));
}

$db = json_decode(file_get_contents($dbFile), true);

// التحقق من وجود الكود
if (!isset($db['codes'][$code])) {
    echo json_encode(['status' => 'error', 'message' => 'كود التفعيل غير موجود']);
    exit;
}

$codeData = $db['codes'][$code];

// التحقق من ربط الجهاز (UDID)
if (!empty($codeData['udid']) && $codeData['udid'] !== $udid) {
    echo json_encode(['status' => 'error', 'message' => 'هذا الكود مفعل على جهاز آخر']);
    exit;
}

// تفعيل الجهاز لأول مرة
if (empty($codeData['udid'])) {
    $db['codes'][$code]['udid'] = $udid;
    $db['codes'][$code]['activated_at'] = date('Y-m-d H:i:s');
    file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
}

echo json_encode([
    'status' => 'success',
    'message' => 'أهلاً بك في WLLFox GPS',
    'expiry' => $codeData['expiry'] ?? 'Permanent'
]);
?>
