<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');

function respond(int $status, array $body): never {
    http_response_code($status);
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

$configFile = __DIR__ . '/../config.php';
if (!is_file($configFile)) respond(503, ['success' => false, 'error' => 'not_installed']);
$config = require $configFile;
if (!empty($config['maintenance'])) respond(503, ['success' => false, 'error' => 'maintenance']);

$input = json_decode(file_get_contents('php://input') ?: '', true);
if (!is_array($input)) respond(400, ['success' => false, 'error' => 'invalid_json']);
$code = strtoupper(trim((string)($input['code'] ?? '')));
$deviceId = trim((string)($input['device_id'] ?? ''));
$projectKey = trim((string)($input['project_key'] ?? ''));
if ($projectKey !== ($config['project_key'] ?? 'gpsq')) respond(403, ['success' => false, 'error' => 'invalid_project']);
if ($code === '' || $deviceId === '') respond(422, ['success' => false, 'error' => 'missing_fields']);

$pdo = new PDO('sqlite:' . $config['database_path']);
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$stmt = $pdo->prepare('SELECT * FROM licenses WHERE code = :code LIMIT 1');
$stmt->execute([':code' => $code]);
$license = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$license) respond(404, ['success' => false, 'error' => 'invalid_code']);
if ((int)$license['is_active'] !== 1) respond(403, ['success' => false, 'error' => 'disabled_code']);
if (!empty($license['expires_at']) && strtotime($license['expires_at']) < time()) respond(403, ['success' => false, 'error' => 'expired_code']);

$deviceHash = hash('sha256', $deviceId);
$countStmt = $pdo->prepare('SELECT COUNT(*) FROM license_devices WHERE license_id = :license_id');
$countStmt->execute([':license_id' => $license['id']]);
$deviceCount = (int)$countStmt->fetchColumn();
$existingStmt = $pdo->prepare('SELECT id FROM license_devices WHERE license_id = :license_id AND device_hash = :device_hash');
$existingStmt->execute([':license_id' => $license['id'], ':device_hash' => $deviceHash]);
$existingDevice = $existingStmt->fetchColumn();
$limit = (int)($license['device_limit'] ?: ($config['device_limit'] ?? 1));
if (!$existingDevice && $deviceCount >= $limit) respond(409, ['success' => false, 'error' => 'device_limit_reached']);

if (!$existingDevice) {
    $insertDevice = $pdo->prepare('INSERT INTO license_devices (license_id, device_hash, created_at, last_seen_at) VALUES (:license_id, :device_hash, :created_at, :last_seen_at)');
    $insertDevice->execute([
        ':license_id' => $license['id'],
        ':device_hash' => $deviceHash,
        ':created_at' => date(DATE_ATOM),
        ':last_seen_at' => date(DATE_ATOM),
    ]);
} else {
    $updateDevice = $pdo->prepare('UPDATE license_devices SET last_seen_at = :last_seen_at WHERE id = :id');
    $updateDevice->execute([':last_seen_at' => date(DATE_ATOM), ':id' => $existingDevice]);
}

$token = bin2hex(random_bytes(32));
$tokenHash = hash('sha256', $token);
$expiresAt = date(DATE_ATOM, time() + (int)($config['session_ttl'] ?? 2592000));
$insertToken = $pdo->prepare('INSERT INTO activation_sessions (license_id, device_hash, token_hash, expires_at, created_at) VALUES (:license_id, :device_hash, :token_hash, :expires_at, :created_at)');
$insertToken->execute([
    ':license_id' => $license['id'],
    ':device_hash' => $deviceHash,
    ':token_hash' => $tokenHash,
    ':expires_at' => $expiresAt,
    ':created_at' => date(DATE_ATOM),
]);

respond(200, [
    'success' => true,
    'status' => 'active',
    'token' => $token,
    'expires_at' => $license['expires_at'],
    'session_expires_at' => $expiresAt,
]);
