<?php
declare(strict_types=1);
$config = require __DIR__ . '/config.php';
date_default_timezone_set($config['timezone']);
$privateDir = dirname($config['db_path']);
if (!is_dir($privateDir) && !mkdir($privateDir, 0700, true) && !is_dir($privateDir)) { throw new RuntimeException('تعذر إنشاء مجلد البيانات الخاص'); }
$db = new PDO('sqlite:' . $config['db_path']);
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$db->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
$db->exec('PRAGMA foreign_keys = ON');
$db->exec('PRAGMA journal_mode = WAL');
$db->exec("CREATE TABLE IF NOT EXISTS licenses (id INTEGER PRIMARY KEY AUTOINCREMENT,code TEXT NOT NULL UNIQUE,duration_days INTEGER NOT NULL DEFAULT 30,status TEXT NOT NULL DEFAULT 'active',device_uuid TEXT DEFAULT NULL,created_at TEXT NOT NULL,activated_at TEXT DEFAULT NULL,expires_at TEXT DEFAULT NULL,last_seen_at TEXT DEFAULT NULL,note TEXT DEFAULT NULL,source_id TEXT DEFAULT NULL,source_bound_at TEXT DEFAULT NULL)");
$db->exec("CREATE TABLE IF NOT EXISTS admin_users (id INTEGER PRIMARY KEY AUTOINCREMENT,username TEXT NOT NULL UNIQUE,password_hash TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)");
$db->exec("CREATE TABLE IF NOT EXISTS admin_login_logs (id INTEGER PRIMARY KEY AUTOINCREMENT,username TEXT NOT NULL,ip_address TEXT NOT NULL,user_agent TEXT DEFAULT NULL,status TEXT NOT NULL,created_at TEXT NOT NULL)");
try { $db->exec('ALTER TABLE licenses ADD COLUMN last_seen_at TEXT DEFAULT NULL'); } catch (Throwable $e) {}
try { $db->exec('ALTER TABLE licenses ADD COLUMN source_id TEXT DEFAULT NULL'); } catch (Throwable $e) {}
try { $db->exec('ALTER TABLE licenses ADD COLUMN source_bound_at TEXT DEFAULT NULL'); } catch (Throwable $e) {}
$adminCount = (int)$db->query('SELECT COUNT(*) FROM admin_users')->fetchColumn();
if ($adminCount === 0) { $stmt=$db->prepare('INSERT INTO admin_users(username,password_hash,created_at,updated_at) VALUES(?,?,?,?)'); $now=date('Y-m-d H:i:s'); $stmt->execute(['admin',password_hash('123456',PASSWORD_DEFAULT),$now,$now]); }
function json_response(array $data,int $status=200):never{http_response_code($status);header('Content-Type: application/json; charset=utf-8');header('Cache-Control: no-store');echo json_encode($data,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);exit;}
function request_input():array{$raw=file_get_contents('php://input');$json=json_decode($raw?:'',true);return is_array($json)?$json:$_POST;}
function normalize_code(string $code):string{return strtoupper(trim($code));}
function generate_code(int $length=20):string{$chars='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';$value='';for($i=0;$i<$length;$i++){$value.=$chars[random_int(0,strlen($chars)-1)];}return 'GPS-'.$value;}
function require_post():void{if(($_SERVER['REQUEST_METHOD']??'GET')!=='POST')json_response(['status'=>'error','message'=>'Method not allowed'],405);}
function require_api_key(array $config):void{$key=(string)($_SERVER['HTTP_X_GPS_API_KEY']??'');if($key===''||!hash_equals($config['api_key'],$key))json_response(['status'=>'error','message'=>'API key غير صحيح'],401);}
function validate_license(PDO $db,string $code,string $device,string $sourceId=''):array{if($code===''||$device==='')json_response(['status'=>'error','message'=>'الكود ومعرف الجهاز مطلوبان'],422);$stmt=$db->prepare('SELECT * FROM licenses WHERE code=?');$stmt->execute([$code]);$license=$stmt->fetch();if(!$license)json_response(['status'=>'error','message'=>'الكود غير موجود'],404);if($license['status']!=='active')json_response(['status'=>'error','message'=>'الكود غير فعال'],403);if($license['device_uuid']&&!hash_equals((string)$license['device_uuid'],$device))json_response(['status'=>'error','message'=>'الكود مرتبط بجهاز آخر'],409);if($sourceId!==''&&!empty($license['source_id'])&&!hash_equals((string)$license['source_id'],$sourceId))json_response(['status'=>'error','message'=>'الكود مرتبط بسورس أداة آخر'],409);if($license['expires_at']&&strtotime($license['expires_at'])<time())json_response(['status'=>'error','message'=>'انتهى الاشتراك'],403);return $license;}
function client_ip():string{return substr((string)($_SERVER['REMOTE_ADDR']??'unknown'),0,64);}
function log_admin_event(PDO $db,string $username,string $status):void{$stmt=$db->prepare('INSERT INTO admin_login_logs(username,ip_address,user_agent,status,created_at) VALUES(?,?,?,?,?)');$stmt->execute([substr($username,0,100),client_ip(),substr((string)($_SERVER['HTTP_USER_AGENT']??''),0,500),substr($status,0,50),date('Y-m-d H:i:s')]);}
