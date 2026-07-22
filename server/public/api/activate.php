<?php
declare(strict_types=1);

require_once __DIR__ . '/config.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Api-Key, X-Device-ID, Authorization');

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

requirePost();
$input = requestInput();
$code = strtoupper(trim((string)($input['code'] ?? $input['license_code'] ?? '')));
$udid = trim((string)($input['device_id'] ?? $input['device_uuid'] ?? $input['udid'] ?? $input['uuid'] ?? ''));
$deviceName = trim((string)($input['device_name'] ?? $input['device_model'] ?? 'iPhone'));
$iosVersion = trim((string)($input['ios_version'] ?? ''));
$appVersion = trim((string)($input['app_version'] ?? ''));

if (!preg_match('/^[A-Z0-9-]{4,64}$/', $code) || $udid === '' || strlen($udid) > 160) {
    logActivity($code ?: null, $udid ?: null, 'activate', 'failed', 'missing_or_invalid_fields');
    jsonResponse(['success'=>false,'status'=>'missing_fields','message'=>'الكود ومعرف الجهاز مطلوبان'], 422);
}

if (setting('maintenance', '0') === '1') {
    logActivity($code, $udid, 'activate', 'failed', 'maintenance');
    jsonResponse([
        'success'=>false,
        'status'=>'maintenance',
        'message'=>setting('server_message', 'الخدمة تحت الصيانة'),
        'maintenance'=>true
    ], 503);
}

$db = getDB();
$stmt = $db->prepare('SELECT * FROM codes WHERE code=? LIMIT 1');
$stmt->execute([$code]);
$row = $stmt->fetch();

if (!$row) {
    logActivity($code, $udid, 'activate', 'failed', 'invalid_code');
    jsonResponse(['success'=>false,'status'=>'invalid_code','message'=>'الكود غير موجود'], 404);
}

if (in_array((string)$row['status'], ['closed','disabled'], true)) {
    logActivity($code, $udid, 'activate', 'failed', 'blocked');
    jsonResponse(['success'=>false,'status'=>'blocked','message'=>'هذا الكود معطل'], 403);
}

$activatedAt = (string)($row['activated_at'] ?: gmdate('Y-m-d H:i:s'));
$durationDays = max(1, (int)($row['duration_days'] ?? 30));
$expiresAt = (string)($row['expires_at'] ?: gmdate('Y-m-d H:i:s', strtotime($activatedAt . ' UTC') + ($durationDays * 86400)));

if (strtotime($expiresAt . ' UTC') <= time()) {
    $db->prepare("UPDATE codes SET status='expired', expires_at=? WHERE code=?")->execute([$expiresAt, $code]);
    logActivity($code, $udid, 'activate', 'failed', 'expired');
    jsonResponse(['success'=>false,'status'=>'expired','message'=>'انتهت صلاحية هذا الكود','expires_at'=>$expiresAt], 403);
}

$countStmt = $db->prepare('SELECT COUNT(*) FROM devices WHERE code=?');
$countStmt->execute([$code]);
$deviceCount = (int)$countStmt->fetchColumn();
$knownStmt = $db->prepare('SELECT 1 FROM devices WHERE code=? AND udid=?');
$knownStmt->execute([$code, $udid]);
$isKnownDevice = (bool)$knownStmt->fetchColumn();
$maxDevices = max(1, (int)($row['max_devices'] ?? 1));

if (!$isKnownDevice && $deviceCount >= $maxDevices) {
    logActivity($code, $udid, 'activate', 'failed', 'device_limit');
    jsonResponse(['success'=>false,'status'=>'device_limit','message'=>'تم الوصول للحد الأقصى من الأجهزة'], 409);
}

$db->beginTransaction();
try {
    $db->prepare("UPDATE codes SET status='linked', udid=COALESCE(udid,?), device_name=?, ios_version=?, app_version=?, activated_at=?, expires_at=? WHERE code=?")
       ->execute([$udid, $deviceName, $iosVersion, $appVersion, $activatedAt, $expiresAt, $code]);

    $db->prepare("INSERT INTO devices(code,udid,device_name,ios_version,app_version)
                  VALUES(?,?,?,?,?)
                  ON CONFLICT(code,udid) DO UPDATE SET
                    last_seen=datetime('now'),
                    device_name=excluded.device_name,
                    ios_version=excluded.ios_version,
                    app_version=excluded.app_version")
       ->execute([$code, $udid, $deviceName, $iosVersion, $appVersion]);
    $db->commit();
} catch (Throwable $e) {
    if ($db->inTransaction()) $db->rollBack();
    error_log('activate.php: ' . $e->getMessage());
    logActivity($code, $udid, 'activate', 'failed', 'server_error');
    jsonResponse(['success'=>false,'status'=>'server_error','message'=>'خطأ داخلي في الخادم'], 500);
}

$timestamp = time();
$signature = hash_hmac('sha256', $code . '|' . $udid . '|' . $timestamp . '|active', (string)GPSQ_HMAC_SECRET);
$remainingDays = max(0, (int)ceil((strtotime($expiresAt . ' UTC') - time()) / 86400));
logActivity($code, $udid, 'activate', 'success', 'active');

jsonResponse([
    'success'=>true,
    'valid'=>true,
    'active'=>true,
    'status'=>'active',
    'message'=>'تم تفعيل الترخيص بنجاح',
    'device_id'=>$udid,
    'device_uuid'=>$udid,
    'activated_at'=>$activatedAt,
    'expires_at'=>$expiresAt,
    'days_remaining'=>$remainingDays,
    'remaining_days'=>$remainingDays,
    'timestamp'=>$timestamp,
    'signature'=>$signature,
    'maintenance'=>false,
    'force_update'=>setting('force_update','0') === '1',
    'minimum_version'=>setting('minimum_version','1.0')
]);
