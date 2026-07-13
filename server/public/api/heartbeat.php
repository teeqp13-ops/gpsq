<?php
/**
 * نقطة نهاية نبضة الحياة — POST /api/heartbeat.php
 *
 * البيانات المطلوبة (JSON body أو POST):
 *   code — كود التفعيل
 *   udid — معرّف الجهاز
 *
 * الاستجابة:
 *   { success, status } حيث status: active | expired | closed | not_found
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

requireApiKey();

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$code  = trim($input['code'] ?? $_POST['code'] ?? '');
$udid  = trim($input['udid'] ?? $_POST['udid'] ?? '');

if ($code === '' || $udid === '') {
    jsonResponse(['success' => false, 'error' => 'الكود و UDID مطلوبان'], 400);
}

$db = getDB();

$stmt = $db->prepare('SELECT status FROM codes WHERE code = ? AND udid = ?');
$stmt->execute([$code, $udid]);
$row = $stmt->fetch();

if (!$row) {
    jsonResponse(['success' => false, 'status' => 'not_found'], 404);
}

if (in_array($row['status'], ['closed', 'expired'], true)) {
    jsonResponse(['success' => false, 'status' => $row['status']], 403);
}

// تسجيل نبضة الحياة
$db->prepare('INSERT INTO heartbeats (code, udid) VALUES (?, ?)')
   ->execute([$code, $udid]);

// تحديث آخر ظهور للجهاز
$db->prepare("UPDATE devices SET last_seen = datetime('now') WHERE code = ? AND udid = ?")
   ->execute([$code, $udid]);

jsonResponse(['success' => true, 'status' => 'active']);
