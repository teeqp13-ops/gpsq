<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
$configFile = __DIR__ . '/../config.php';
if (!is_file($configFile)) {
    http_response_code(503);
    echo json_encode(['success' => false, 'status' => 'not_installed'], JSON_UNESCAPED_UNICODE);
    exit;
}
$config = require $configFile;
echo json_encode([
    'success' => true,
    'project' => $config['project_key'] ?? 'gpsq',
    'maintenance' => (bool)($config['maintenance'] ?? false),
    'server_time' => date(DATE_ATOM),
], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
