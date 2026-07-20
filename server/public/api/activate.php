<?php
declare(strict_types=1);

require_once __DIR__ . '/config.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Api-Key, X-GPS-Api-Key, Authorization');

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

requirePost();
requireApiKey();

$input       = requestInput();
$code        = strtoupper(trim((string)($input['code'] ?? '')));
$udid        = trim((string)($input['udid'] ?? $input['device_uuid'] ?? ''));
$iosVersion  = trim((string)($input['ios_version'] ?? ''));
$appVersion  = trim((string)($input['app_version'] ?? ''));
$deviceName  = trim((string)($input['device_name'] ?? 'iPhone'));

if ($code === '' || $udid === '') {
    jsonResponse(['success' => false, 'status' => 'missing_fields', 'error' => 'الكود ومعرف الجهاز مطلوبان'], 422);
}

$db = getDB();
$stmt = $db->prepare('SELECT * FROM codes WHERE code = ? LIMIT 1');
$stmt->execute([$code]);
$row = $stmt->fetch();

if (!$row) {
    jsonResponse(['success' => false, 'status' => 'invalid_code', 'error' => 'الكود غير موجود'], 404);
}

if (($row['status'] ?? '') === 'closed') {
    jsonResponse(['success' => false, 'status' => 'blocked', 'error' => 'هذا الكود مغلق'], 403);
}

if (($row['status'] ?? '') === 'expired') {
    jsonResponse(['success' => false, 'status' => 'expired', 'error' => 'انتهت صلاحية هذا الكود'], 403);
}

if (($row['status'] ?? '') === 'linked' && !empty($row['udid']) && !hash_equals((string)$row['udid'], $udid)) {
    jsonResponse(['success' => false, 'status' => 'device_mismatch', 'error' => 'هذا الكود مرتبط بجهاز آخر'], 409);
}

$activatedAt = !empty($row['activated_at']) ? (string)$row['activated_at'] : gmdate('Y-m-d H:i:s');
$expiresAt = gmdate('Y-m-d H:i:s', strtotime($activatedAt . ' UTC') + (30 * 86400));

if (strtotime($expiresAt . ' UTC') <= time()) {
    $db->prepare("UPDATE codes SET status='expired' WHERE code=?")->execute([$code]);
    jsonResponse(['success' => false, 'status' => 'expired', 'error' => 'انتهت صلاحية هذا الكود', 'expires_at' => $expiresAt], 403);
}

$db->beginTransaction();
try {
    $db->prepare("UPDATE codes
                  SET status='linked', udid=?, device_name=?, ios_version=?, app_version=?, activated_at=?
                  WHERE code=?")
       ->execute([$udid, $deviceName, $iosVersion, $appVersion, $activatedAt, $code]);

    $db->prepare("INSERT INTO devices (code, udid, device_name, ios_version, app_version)
                  VALUES (?, ?, ?, ?, ?)
                  ON CONFLICT(code, udid) DO UPDATE SET
                      last_seen=datetime('now'),
                      device_name=excluded.device_name,
                      app_version=excluded.app_version,
                      ios_version=excluded.ios_version")
       ->execute([$code, $udid, $deviceName, $iosVersion, $appVersion]);

    $db->commit();
} catch (Throwable $e) {
    if ($db->inTransaction()) {
        $db->rollBack();
    }
    error_log('activate.php: ' . $e->getMessage());
    jsonResponse(['success' => false, 'status' => 'server_error', 'error' => 'خطأ داخلي في الخادم'], 500);
}

$token = hash_hmac('sha256', $code . '|' . $udid . '|' . $activatedAt, (string)GPSQ_API_KEY);
$remainingDays = max(0, (int)ceil((strtotime($expiresAt . ' UTC') - time()) / 86400));

jsonResponse([
    'success' => true,
    'valid' => true,
    'status' => 'active',
    'message' => 'تم تفعيل الترخيص بنجاح',
    'token' => $token,
    'activated_at' => $activatedAt,
    'expires_at' => $expiresAt,
    'remaining_days' => $remainingDays,
    'device_uuid' => $udid,
]);
