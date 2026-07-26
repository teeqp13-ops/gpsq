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

    $input = json_decode(file_get_contents('php://input') ?: '', true);
    if (!is_array($input)) respond(400, ['success' => false, 'error' => 'invalid_json']);
    $projectKey = trim((string)($input['project_key'] ?? ''));
    $token = trim((string)($input['token'] ?? ''));
    $deviceId = trim((string)($input['device_id'] ?? ''));
    if ($projectKey !== ($config['project_key'] ?? 'gpsq')) respond(403, ['success' => false, 'error' => 'invalid_project']);
    if ($token === '' || $deviceId === '') respond(422, ['success' => false, 'error' => 'missing_fields']);

    $pdo = new PDO('sqlite:' . $config['database_path']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

    $stmt = $pdo->prepare('SELECT s.id AS session_id, s.expires_at AS session_expires_at, l.id AS license_id, l.expires_at AS license_expires_at, l.is_active, l.device_limit FROM activation_sessions s JOIN licenses l ON l.id = s.license_id WHERE s.token_hash = :token_hash AND s.device_hash = :device_hash LIMIT 1');
    $stmt->execute([':token_hash' => hash('sha256', $token), ':device_hash' => hash('sha256', $deviceId)]);
    $row = $stmt->fetch();
    if (!$row) respond(401, ['success' => false, 'error' => 'invalid_session']);
    if ((int)$row['is_active'] !== 1) respond(403, ['success' => false, 'error' => 'disabled_code']);
    if (strtotime((string)$row['session_expires_at']) < time()) respond(401, ['success' => false, 'error' => 'session_expired']);
    if (!empty($row['license_expires_at']) && strtotime((string)$row['license_expires_at']) < time()) respond(403, ['success' => false, 'error' => 'expired_code']);

    $now = date(DATE_ATOM);
    $pdo->prepare('UPDATE activation_sessions SET last_seen_at = :now WHERE id = :id')->execute([':now' => $now, ':id' => $row['session_id']]);
    $pdo->prepare('UPDATE license_devices SET last_seen_at = :now WHERE license_id = :license_id AND device_hash = :device_hash')->execute([':now' => $now, ':license_id' => $row['license_id'], ':device_hash' => hash('sha256', $deviceId)]);

    respond(200, [
        'success' => true,
        'status' => 'active',
        'project' => $config['project_key'] ?? 'gpsq',
        'maintenance' => false,
        'expires_at' => $row['license_expires_at'],
        'session_expires_at' => $row['session_expires_at'],
        'device_limit' => (int)$row['device_limit'],
        'server_time' => $now,
    ]);
} catch (Throwable $exception) {
    respond(500, ['success' => false, 'error' => 'server_error']);
}
