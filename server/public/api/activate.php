<?php
/**
 * نقطة نهاية تفعيل الكود — POST /api/activate.php
 *
 * البيانات المطلوبة (JSON body أو POST):
 *   code        — كود التفعيل (8 خانات)
 *   udid        — معرّف الجهاز الفريد
 *   ios_version — إصدار iOS (اختياري)
 *   app_version — إصدار التطبيق (اختياري)
 *   device_name — اسم الجهاز (اختياري)
 */

require_once __DIR__ . '/config.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Api-Key');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(['success' => false, 'error' => 'يُسمح فقط بطلبات POST'], 405);
}

// قراءة البيانات من JSON body أو POST form
$input       = json_decode(file_get_contents('php://input'), true) ?: [];
$code        = trim($input['code']        ?? $_POST['code']        ?? '');
$udid        = trim($input['udid']        ?? $_POST['udid']        ?? '');
$ios_version = trim($input['ios_version'] ?? $_POST['ios_version'] ?? '');
$app_version = trim($input['app_version'] ?? $_POST['app_version'] ?? '');
$device_name = trim($input['device_name'] ?? $_POST['device_name'] ?? '');

if ($code === '' || $udid === '') {
    jsonResponse(['success' => false, 'error' => 'الكود و UDID مطلوبان'], 400);
}

$db = getDB();

// جلب بيانات الكود
$stmt = $db->prepare('SELECT * FROM codes WHERE code = ?');
$stmt->execute([$code]);
$row = $stmt->fetch();

if (!$row) {
    jsonResponse(['success' => false, 'error' => 'الكود غير موجود'], 404);
}

switch ($row['status']) {
    case 'closed':
        jsonResponse(['success' => false, 'error' => 'هذا الكود مغلق'], 403);
        break;
    case 'expired':
        jsonResponse(['success' => false, 'error' => 'انتهت صلاحية هذا الكود'], 403);
        break;
    case 'unused':
        // تفعيل الكود لأول مرة
        $db->prepare("UPDATE codes
                      SET status='linked', udid=?, device_name=?,
                          ios_version=?, app_version=?,
                          activated_at=datetime('now')
                      WHERE code=?")
           ->execute([$udid, $device_name, $ios_version, $app_version, $code]);
        break;
    case 'linked':
        // التحقق من أن نفس الجهاز يُعيد التفعيل
        if ($row['udid'] !== $udid) {
            jsonResponse(['success' => false, 'error' => 'هذا الكود مرتبط بجهاز آخر'], 403);
        }
        break;
}

// تسجيل/تحديث الجهاز في جدول الأجهزة
$db->prepare("INSERT INTO devices (code, udid, device_name, ios_version, app_version)
              VALUES (?, ?, ?, ?, ?)
              ON CONFLICT(code, udid) DO UPDATE
                  SET last_seen   = datetime('now'),
                      app_version = excluded.app_version,
                      ios_version = excluded.ios_version")
   ->execute([$code, $udid, $device_name, $ios_version, $app_version]);

jsonResponse([
    'success' => true,
    'status'  => 'active',
]);
