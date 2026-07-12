<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
$checks = [
  'php' => PHP_VERSION,
  'pdo_sqlite' => extension_loaded('pdo_sqlite'),
  'storage_writable' => is_writable(dirname(__DIR__) . '/storage'),
];
http_response_code(($checks['pdo_sqlite'] && $checks['storage_writable']) ? 200 : 500);
echo json_encode(['status' => http_response_code() === 200 ? 'ok' : 'error', 'checks' => $checks], JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
