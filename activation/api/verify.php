<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
function respond(int $status, array $body): never { http_response_code($status); echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES); exit; }
$configFile = __DIR__ . '/../config.php';
if (!is_file($configFile)) respond(503, ['success'=>false,'error'=>'not_installed']);
$config = require $configFile;
$input = json_decode(file_get_contents('php://input') ?: '', true);
if (!is_array($input)) respond(400, ['success'=>false,'error'=>'invalid_json']);
$token = trim((string)($input['token'] ?? ''));
$deviceId = trim((string)($input['device_id'] ?? ''));
if ($token === '' || $deviceId === '') respond(422, ['success'=>false,'error'=>'missing_fields']);
$pdo = new PDO('sqlite:' . $config['database_path']);
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$stmt = $pdo->prepare('SELECT s.expires_at AS session_expires_at, l.expires_at AS license_expires_at, l.is_active FROM activation_sessions s JOIN licenses l ON l.id=s.license_id WHERE s.token_hash=:token_hash AND s.device_hash=:device_hash LIMIT 1');
$stmt->execute([':token_hash'=>hash('sha256',$token), ':device_hash'=>hash('sha256',$deviceId)]);
$row = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$row) respond(401, ['success'=>false,'error'=>'invalid_session']);
if ((int)$row['is_active'] !== 1) respond(403, ['success'=>false,'error'=>'disabled_code']);
if (strtotime($row['session_expires_at']) < time()) respond(401, ['success'=>false,'error'=>'session_expired']);
if (!empty($row['license_expires_at']) && strtotime($row['license_expires_at']) < time()) respond(403, ['success'=>false,'error'=>'expired_code']);
respond(200, ['success'=>true,'status'=>'active','maintenance'=>(bool)($config['maintenance'] ?? false),'expires_at'=>$row['license_expires_at']]);
