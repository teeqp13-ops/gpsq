<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate');

function respond(int $status, array $body) {
    http_response_code($status);
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

try {
    $configFile = __DIR__ . '/../config.php';
    if (!is_file($configFile)) respond(503, ['success' => false, 'error' => 'not_installed']);
    $config = require $configFile;
    if (!empty($config['maintenance'])) respond(503, ['success' => false, 'error' => 'maintenance']);
    if (!extension_loaded('pdo_sqlite')) respond(500, ['success' => false, 'error' => 'sqlite_unavailable']);

    $input = json_decode(file_get_contents('php://input') ?: '', true);
    if (!is_array($input)) respond(400, ['success' => false, 'error' => 'invalid_json']);
    $code = strtoupper(trim((string)($input['code'] ?? $input['license_code'] ?? '')));
    $deviceId = trim((string)($input['device_id'] ?? ''));
    $projectKey = trim((string)($input['project_key'] ?? ''));
    if ($projectKey !== ($config['project_key'] ?? 'gpsq')) respond(403, ['success' => false, 'error' => 'invalid_project']);
    if ($code === '' || $deviceId === '') respond(422, ['success' => false, 'error' => 'missing_fields']);
    if (!preg_match('/^[A-Z0-9]{8}$/', $code)) respond(422, ['success' => false, 'error' => 'invalid_code_format']);

    $pdo = new PDO('sqlite:' . $config['database_path']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    $pdo->exec('PRAGMA foreign_keys = ON');

    $stmt = $pdo->prepare('SELECT * FROM licenses WHERE code = :code LIMIT 1');
    $stmt->execute([':code' => $code]);
    $license = $stmt->fetch();
    if (!$license) respond(404, ['success' => false, 'error' => 'invalid_code']);
    if ((int)$license['is_active'] !== 1) respond(403, ['success' => false, 'error' => 'disabled_code']);
    if (!empty($license['expires_at']) && strtotime($license['expires_at']) < time()) respond(403, ['success' => false, 'error' => 'expired_code']);

    $deviceHash = hash('sha256', $deviceId);
    $pdo->beginTransaction();
    $countStmt = $pdo->prepare('SELECT COUNT(*) FROM license_devices WHERE license_id = :license_id');
    $countStmt->execute([':license_id' => $license['id']]);
    $deviceCount = (int)$countStmt->fetchColumn();
    $existingStmt = $pdo->prepare('SELECT id FROM license_devices WHERE license_id = :license_id AND device_hash = :device_hash');
    $existingStmt->execute([':license_id' => $license['id'], ':device_hash' => $deviceHash]);
    $existingDevice = $existingStmt->fetchColumn();
    $limit = max(1, (int)($license['device_limit'] ?: ($config['device_limit'] ?? 1)));
    if (!$existingDevice && $deviceCount >= $limit) {
        $pdo->rollBack();
        respond(409, ['success' => false, 'error' => 'device_limit_reached']);
    }

    $now = date(DATE_ATOM);
    if (!$existingDevice) {
        $insertDevice = $pdo->prepare('INSERT INTO license_devices (license_id, device_hash, created_at, last_seen_at) VALUES (:license_id, :device_hash, :created_at, :last_seen_at)');
        $insertDevice->execute([':license_id' => $license['id'], ':device_hash' => $deviceHash, ':created_at' => $now, ':last_seen_at' => $now]);
    } else {
        $updateDevice = $pdo->prepare('UPDATE license_devices SET last_seen_at = :last_seen_at WHERE id = :id');
        $updateDevice->execute([':last_seen_at' => $now, ':id' => $existingDevice]);
    }

    $token = bin2hex(random_bytes(32));
    $tokenHash = hash('sha256', $token);
    $sessionExpiresAt = date(DATE_ATOM, time() + (int)($config['session_ttl'] ?? 2592000));
    $pdo->prepare('DELETE FROM activation_sessions WHERE expires_at < :now')->execute([':now' => $now]);
    $insertToken = $pdo->prepare('INSERT INTO activation_sessions (license_id, device_hash, token_hash, expires_at, created_at, last_seen_at) VALUES (:license_id, :device_hash, :token_hash, :expires_at, :created_at, :last_seen_at)');
    $insertToken->execute([':license_id' => $license['id'], ':device_hash' => $deviceHash, ':token_hash' => $tokenHash, ':expires_at' => $sessionExpiresAt, ':created_at' => $now, ':last_seen_at' => $now]);

    $ip = isset($_SERVER['REMOTE_ADDR']) ? (string)$_SERVER['REMOTE_ADDR'] : null;
    $log = $pdo->prepare('INSERT INTO activation_logs (license_id, event, device_hash, ip_address, details, created_at) VALUES (:license_id, :event, :device_hash, :ip, :details, :created_at)');
    $log->execute([':license_id' => $license['id'], ':event' => 'activated', ':device_hash' => $deviceHash, ':ip' => $ip, ':details' => json_encode(['bundle_id' => $input['bundle_id'] ?? null, 'app_version' => $input['app_version'] ?? null], JSON_UNESCAPED_UNICODE), ':created_at' => $now]);
    $pdo->commit();

    respond(200, [
        'success' => true,
        'status' => 'active',
        'project' => $config['project_key'] ?? 'gpsq',
        'token' => $token,
        'expires_at' => $license['expires_at'],
        'session_expires_at' => $sessionExpiresAt,
        'device_limit' => $limit,
    ]);
} catch (Throwable $exception) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) $pdo->rollBack();
    respond(500, ['success' => false, 'error' => 'server_error']);
}
