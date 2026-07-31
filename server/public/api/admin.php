<?php
declare(strict_types=1);

require_once __DIR__ . '/config.php';

header('Access-Control-Allow-Origin: https://wolf-gps-control.chatgpt-sites.com');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Api-Key, Authorization');

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

requireApiKey();
$db = getDB();

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'GET') {
    $resource = (string)($_GET['resource'] ?? 'dashboard');
    if ($resource !== 'dashboard') {
        jsonResponse(['success' => false, 'message' => 'المورد غير معروف'], 404);
    }

    $statusCounts = ['unused' => 0, 'linked' => 0, 'disabled' => 0, 'expired' => 0, 'closed' => 0];
    foreach ($db->query('SELECT status, COUNT(*) AS total FROM codes GROUP BY status')->fetchAll() as $row) {
        $status = (string)$row['status'];
        if (array_key_exists($status, $statusCounts)) $statusCounts[$status] = (int)$row['total'];
    }

    $codes = $db->query("
        SELECT c.*,
               (SELECT COUNT(*) FROM devices d WHERE d.code=c.code) AS device_count
        FROM codes c
        ORDER BY c.created_at DESC
        LIMIT 1000
    ")->fetchAll();

    $devices = $db->query("
        SELECT id, code, udid, device_name, ios_version, app_version, first_seen, last_seen
        FROM devices
        ORDER BY last_seen DESC
        LIMIT 1000
    ")->fetchAll();

    $logs = $db->query("
        SELECT l.id, l.action, l.result, l.code, l.udid, l.message, l.ip, l.created_at,
               (SELECT d.device_name FROM devices d WHERE d.udid=l.udid ORDER BY d.last_seen DESC LIMIT 1) AS device_name
        FROM activity_logs l
        ORDER BY l.created_at DESC
        LIMIT 300
    ")->fetchAll();

    $settingsRows = $db->query('SELECT name, value FROM settings')->fetchAll();
    $settings = [];
    foreach ($settingsRows as $row) $settings[(string)$row['name']] = (string)$row['value'];

    jsonResponse([
        'success' => true,
        'stats' => [
            'total' => array_sum($statusCounts),
            'unused' => $statusCounts['unused'],
            'linked' => $statusCounts['linked'],
            'disabled' => $statusCounts['disabled'],
            'expired' => $statusCounts['expired'],
            'closed' => $statusCounts['closed'],
            'devices' => (int)$db->query('SELECT COUNT(DISTINCT udid) FROM devices')->fetchColumn(),
            'active_today' => (int)$db->query("SELECT COUNT(*) FROM activity_logs WHERE result='success' AND created_at >= datetime('now','start of day')")->fetchColumn(),
        ],
        'codes' => $codes,
        'devices' => $devices,
        'logs' => $logs,
        'settings' => [
            'maintenance' => ($settings['maintenance'] ?? '0') === '1',
            'force_update' => ($settings['force_update'] ?? '0') === '1',
            'minimum_version' => $settings['minimum_version'] ?? '1.0',
            'server_message' => $settings['server_message'] ?? '',
        ],
    ]);
}

requirePost();
$input = requestInput();
$action = (string)($input['action'] ?? '');

function adminCode(int $length): string
{
    $length = max(8, min($length, 20));
    $code = (string)random_int(1, 9);
    for ($index = 1; $index < $length; $index++) {
        $code .= (string)random_int(0, 9);
    }
    return $code;
}

function adminAudit(string $action, string $message, ?string $code = null): void
{
    logActivity($code, null, 'admin_' . $action, 'success', $message);
}

if ($action === 'create_codes') {
    $count = max(1, min((int)($input['count'] ?? 1), 500));
    $length = max(8, min((int)($input['length'] ?? 12), 20));
    $durationDays = max(1, min((int)($input['duration_days'] ?? 30), 3650));
    $maxDevices = max(1, min((int)($input['max_devices'] ?? 1), 20));
    $note = trim(substr((string)($input['note'] ?? ''), 0, 240));
    $created = [];

    $db->beginTransaction();
    try {
        $insert = $db->prepare('INSERT INTO codes(code,duration_days,max_devices,note) VALUES(?,?,?,?)');
        while (count($created) < $count) {
            $code = adminCode($length);
            try {
                $insert->execute([$code, $durationDays, $maxDevices, $note ?: null]);
                $created[] = $code;
            } catch (PDOException $exception) {
                if ((string)$exception->getCode() !== '23000') throw $exception;
            }
        }
        $db->commit();
    } catch (Throwable $exception) {
        if ($db->inTransaction()) $db->rollBack();
        error_log('admin create_codes: ' . $exception->getMessage());
        jsonResponse(['success' => false, 'message' => 'تعذر إنشاء الأكواد'], 500);
    }
    adminAudit('create_codes', 'created_' . count($created) . '_codes');
    jsonResponse(['success' => true, 'message' => 'تم إنشاء ' . count($created) . ' كود', 'codes' => $created]);
}

if ($action === 'update_code') {
    $code = preg_replace('/\D+/', '', (string)($input['code'] ?? ''));
    $status = (string)($input['status'] ?? '');
    if (!preg_match('/^\d{8,20}$/', $code)) {
        jsonResponse(['success' => false, 'message' => 'صيغة الكود غير صالحة'], 422);
    }
    if (!in_array($status, ['unused', 'linked', 'disabled', 'expired', 'closed'], true)) {
        jsonResponse(['success' => false, 'message' => 'حالة الكود غير صالحة'], 422);
    }
    $db->beginTransaction();
    try {
        if ($status === 'unused') {
            $db->prepare('DELETE FROM tokens WHERE code=?')->execute([$code]);
            $db->prepare('DELETE FROM devices WHERE code=?')->execute([$code]);
            $statement = $db->prepare("UPDATE codes SET status='unused',udid=NULL,device_name=NULL,ios_version=NULL,app_version=NULL,activated_at=NULL,expires_at=NULL WHERE code=?");
            $statement->execute([$code]);
        } else {
            $statement = $db->prepare('UPDATE codes SET status=? WHERE code=?');
            $statement->execute([$status, $code]);
        }
        if ($statement->rowCount() === 0) throw new RuntimeException('not_found');
        if (in_array($status, ['disabled', 'closed'], true)) {
            $db->prepare('DELETE FROM tokens WHERE code=?')->execute([$code]);
        }
        $db->commit();
    } catch (Throwable $exception) {
        if ($db->inTransaction()) $db->rollBack();
        jsonResponse(['success' => false, 'message' => $exception->getMessage() === 'not_found' ? 'الكود غير موجود' : 'تعذر تحديث الكود'], $exception->getMessage() === 'not_found' ? 404 : 500);
    }
    adminAudit('update_code', 'status_' . $status, $code);
    jsonResponse(['success' => true, 'message' => 'تم تحديث حالة الكود']);
}

if ($action === 'reset_code') {
    $code = preg_replace('/\D+/', '', (string)($input['code'] ?? ''));
    if (!preg_match('/^\d{8,20}$/', $code)) {
        jsonResponse(['success' => false, 'message' => 'صيغة الكود غير صالحة'], 422);
    }
    $db->beginTransaction();
    try {
        $db->prepare('DELETE FROM tokens WHERE code=?')->execute([$code]);
        $db->prepare('DELETE FROM devices WHERE code=?')->execute([$code]);
        $statement = $db->prepare("UPDATE codes SET status='unused',udid=NULL,device_name=NULL,ios_version=NULL,app_version=NULL,activated_at=NULL,expires_at=NULL WHERE code=?");
        $statement->execute([$code]);
        if ($statement->rowCount() === 0) throw new RuntimeException('not_found');
        $db->commit();
    } catch (Throwable $exception) {
        if ($db->inTransaction()) $db->rollBack();
        jsonResponse(['success' => false, 'message' => 'تعذر إعادة ضبط الكود'], $exception->getMessage() === 'not_found' ? 404 : 500);
    }
    adminAudit('reset_code', 'devices_unlinked', $code);
    jsonResponse(['success' => true, 'message' => 'تم فصل الأجهزة وإعادة ضبط الكود']);
}

if ($action === 'unlink_device') {
    $id = (int)($input['id'] ?? 0);
    $lookup = $db->prepare('SELECT code FROM devices WHERE id=?');
    $lookup->execute([$id]);
    $code = (string)($lookup->fetchColumn() ?: '');
    if ($code === '') jsonResponse(['success' => false, 'message' => 'الجهاز غير موجود'], 404);

    $db->beginTransaction();
    try {
        $db->prepare('DELETE FROM tokens WHERE code=? AND udid=(SELECT udid FROM devices WHERE id=?)')->execute([$code, $id]);
        $db->prepare('DELETE FROM devices WHERE id=?')->execute([$id]);
        $remaining = $db->prepare('SELECT COUNT(*) FROM devices WHERE code=?');
        $remaining->execute([$code]);
        if ((int)$remaining->fetchColumn() === 0) {
            $db->prepare("UPDATE codes SET status='unused',udid=NULL,device_name=NULL,ios_version=NULL,app_version=NULL,activated_at=NULL,expires_at=NULL WHERE code=?")
               ->execute([$code]);
        }
        $db->commit();
    } catch (Throwable $exception) {
        if ($db->inTransaction()) $db->rollBack();
        jsonResponse(['success' => false, 'message' => 'تعذر فصل الجهاز'], 500);
    }
    adminAudit('unlink_device', 'device_' . $id . '_unlinked', $code);
    jsonResponse(['success' => true, 'message' => 'تم فصل الجهاز']);
}

if ($action === 'delete_code') {
    $code = preg_replace('/\D+/', '', (string)($input['code'] ?? ''));
    if (!preg_match('/^\d{8,20}$/', $code)) {
        jsonResponse(['success' => false, 'message' => 'صيغة الكود غير صالحة'], 422);
    }
    $statement = $db->prepare('DELETE FROM codes WHERE code=?');
    $statement->execute([$code]);
    if ($statement->rowCount() === 0) jsonResponse(['success' => false, 'message' => 'الكود غير موجود'], 404);
    adminAudit('delete_code', 'code_deleted', $code);
    jsonResponse(['success' => true, 'message' => 'تم حذف الكود']);
}

if ($action === 'save_settings') {
    $values = [
        'maintenance' => !empty($input['maintenance']) ? '1' : '0',
        'force_update' => !empty($input['force_update']) ? '1' : '0',
        'minimum_version' => trim(substr((string)($input['minimum_version'] ?? '1.0'), 0, 32)),
        'server_message' => trim(substr((string)($input['server_message'] ?? ''), 0, 500)),
    ];
    $statement = $db->prepare("INSERT INTO settings(name,value,updated_at) VALUES(?,?,datetime('now'))
                               ON CONFLICT(name) DO UPDATE SET value=excluded.value,updated_at=datetime('now')");
    foreach ($values as $name => $value) $statement->execute([$name, $value]);
    adminAudit('save_settings', 'settings_updated');
    jsonResponse(['success' => true, 'message' => 'تم حفظ إعدادات الخادم']);
}

jsonResponse(['success' => false, 'message' => 'الإجراء غير معروف'], 404);
