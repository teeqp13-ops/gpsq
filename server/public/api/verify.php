<?php
declare(strict_types=1);

require_once __DIR__ . '/config.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

requirePost();
$input = requestInput();
$token = trim((string)($input['token'] ?? ''));
$udid = trim((string)($input['device_id'] ?? $input['udid'] ?? ''));

if ($token === '' || $udid === '') {
    jsonResponse(['success'=>false,'status'=>'missing_fields','message'=>'بيانات الجلسة غير مكتملة'], 422);
}

$db = getDB();
$statement = $db->prepare("
    SELECT t.code,t.expires_at,c.status,c.expires_at AS code_expires_at
    FROM tokens t
    INNER JOIN codes c ON c.code=t.code
    WHERE t.token_hash=? AND t.udid=?
    LIMIT 1
");
$statement->execute([hash('sha256', $token), $udid]);
$session = $statement->fetch();

if (!$session) {
    jsonResponse(['success'=>false,'status'=>'invalid_session','message'=>'جلسة التفعيل غير صالحة'], 401);
}

$expiresAt = (string)($session['code_expires_at'] ?: $session['expires_at']);
if (in_array((string)$session['status'], ['closed', 'disabled', 'expired'], true) ||
    strtotime($expiresAt . ' UTC') <= time()) {
    if (!in_array((string)$session['status'], ['closed', 'disabled'], true)) {
        $db->prepare("UPDATE codes SET status='expired' WHERE code=?")
           ->execute([(string)$session['code']]);
    }
    $status = (string)$session['status'];
    jsonResponse([
        'success'=>false,
        'status'=>$status === 'disabled' ? 'disabled_code' : ($status === 'closed' ? 'closed_code' : 'session_expired'),
        'message'=>$status === 'disabled' ? 'تم تعطيل هذا الكود' : ($status === 'closed' ? 'تم إيقاف هذا الكود' : 'انتهت صلاحية التفعيل')
    ], 403);
}

$db->prepare("UPDATE tokens SET last_seen=datetime('now') WHERE token_hash=?")
   ->execute([hash('sha256', $token)]);
$db->prepare("UPDATE devices SET last_seen=datetime('now') WHERE code=? AND udid=?")
   ->execute([(string)$session['code'], $udid]);
logActivity((string)$session['code'], $udid, 'verify', 'success', 'active_session');

jsonResponse([
    'success'=>true,
    'valid'=>true,
    'active'=>true,
    'status'=>'active',
    'code'=>(string)$session['code'],
    'expires_at'=>$expiresAt,
]);
