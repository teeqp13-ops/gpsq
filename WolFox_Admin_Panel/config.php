<?php
// ===== WolFox Admin Panel - Config =====
error_reporting(E_ALL & ~E_DEPRECATED & ~E_NOTICE);
session_start();

define('DB_PATH', __DIR__ . '/admin/database.sqlite');
define('ADMIN_PASSWORD_FALLBACK', '');
define('DEFAULT_HOSTINGER_USER', 'your-hostinger-user');
define('DEFAULT_HOSTINGER_PASS', 'your-hostinger-pass');

function db() {
    static $pdo = null;
    if ($pdo === null) {
        $pdo = new PDO('sqlite:' . DB_PATH);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $pdo->exec("CREATE TABLE IF NOT EXISTS codes (code TEXT PRIMARY KEY,status TEXT NOT NULL DEFAULT 'unused',device_id TEXT DEFAULT NULL,device_model TEXT DEFAULT NULL,note TEXT DEFAULT NULL,created_at TEXT NOT NULL,activated_at TEXT DEFAULT NULL,expires_at TEXT DEFAULT NULL)");
        $pdo->exec("CREATE TABLE IF NOT EXISTS projects (id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,subdomain TEXT NOT NULL UNIQUE,type TEXT NOT NULL,status TEXT DEFAULT 'active',description TEXT,created_at TEXT NOT NULL,updated_at TEXT)");
        $pdo->exec("CREATE TABLE IF NOT EXISTS stats (date TEXT PRIMARY KEY,total_activations INTEGER DEFAULT 0,total_users INTEGER DEFAULT 0,total_projects INTEGER DEFAULT 0)");
        $pdo->exec("CREATE TABLE IF NOT EXISTS feature_flags (flag_key TEXT PRIMARY KEY,enabled INTEGER NOT NULL DEFAULT 1,label TEXT DEFAULT NULL,updated_at TEXT DEFAULT NULL)");
        $pdo->exec("CREATE TABLE IF NOT EXISTS admin_settings (setting_key TEXT PRIMARY KEY,setting_value TEXT NOT NULL,updated_at TEXT DEFAULT NULL)");
        $pdo->exec("CREATE TABLE IF NOT EXISTS uploads (id INTEGER PRIMARY KEY AUTOINCREMENT,filename TEXT NOT NULL,original_name TEXT NOT NULL,file_size INTEGER NOT NULL DEFAULT 0,file_type TEXT DEFAULT NULL,uploaded_at TEXT NOT NULL)");
        $pdo->exec("CREATE TABLE IF NOT EXISTS build_config (id INTEGER PRIMARY KEY CHECK (id = 1),repo_owner TEXT DEFAULT 'teeqp13-ops',repo_name TEXT DEFAULT 'gpsq',workflow_file TEXT DEFAULT 'build.yml',branch TEXT DEFAULT 'main',github_token TEXT DEFAULT NULL,updated_at TEXT DEFAULT NULL)");
        $chkBuild = $pdo->query("SELECT COUNT(*) c FROM build_config")->fetch();
        if ((int)$chkBuild['c'] === 0) $pdo->exec("INSERT INTO build_config (id, repo_owner, repo_name, workflow_file, branch) VALUES (1, 'teeqp13-ops', 'gpsq', 'build.yml', 'main')");
        $defaultFlags = array('floating_button'=>'الزر العائم فوق التطبيقات','tab_map'=>'تبويب الخريطة','tab_favorites'=>'تبويب المفضلة','tab_device'=>'تبويب إدارة الجهاز','tab_settings'=>'تبويب الإعدادات');
        $chk=$pdo->prepare("SELECT 1 FROM feature_flags WHERE flag_key = ?");
        $ins=$pdo->prepare("INSERT INTO feature_flags (flag_key, enabled, label, updated_at) VALUES (?, 1, ?, ?)");
        foreach($defaultFlags as $flagKey=>$flagLabel){$chk->execute(array($flagKey));if(!$chk->fetch())$ins->execute(array($flagKey,$flagLabel,date('Y-m-d H:i:s')));}
    }
    return $pdo;
}
function json_out($data,$http_code=200){http_response_code($http_code);header('Content-Type: application/json; charset=utf-8');echo json_encode($data,JSON_UNESCAPED_UNICODE);exit;}
function is_admin(){return isset($_SESSION['wf_admin'])&&$_SESSION['wf_admin']===true;}
function redirect_to_login(){if(!is_admin()){header('Location: index.php');exit;}}
function wf_admin_password_hash(){ $stmt=db()->prepare("SELECT setting_value FROM admin_settings WHERE setting_key='admin_password_hash'");$stmt->execute();$row=$stmt->fetch(PDO::FETCH_ASSOC);return $row?$row['setting_value']:''; }
function wf_verify_admin_password($password){$hash=wf_admin_password_hash();if($hash!=='')return password_verify($password,$hash);$env=getenv('WOLFOX_ADMIN_PASSWORD');if($env!==false&&$env!=='')return hash_equals($env,$password);return ADMIN_PASSWORD_FALLBACK!==''&&hash_equals(ADMIN_PASSWORD_FALLBACK,$password);}
function wf_set_admin_password($password){$hash=password_hash($password,PASSWORD_DEFAULT);$stmt=db()->prepare("INSERT INTO admin_settings (setting_key, setting_value, updated_at) VALUES ('admin_password_hash', ?, ?) ON CONFLICT(setting_key) DO UPDATE SET setting_value=excluded.setting_value, updated_at=excluded.updated_at");return $stmt->execute(array($hash,date('Y-m-d H:i:s')));}
define('WF_ENCRYPTION_KEY','wolfox_build_9k3x2m_change_me');
function wf_encrypt($plain){if($plain===null||$plain==='')return null;$key=hash('sha256',WF_ENCRYPTION_KEY,true);$iv=openssl_random_pseudo_bytes(16);$cipher=openssl_encrypt($plain,'AES-256-CBC',$key,OPENSSL_RAW_DATA,$iv);return base64_encode($iv.$cipher);}
function wf_decrypt($encoded){if($encoded===null||$encoded==='')return null;$raw=base64_decode($encoded);if($raw===false||strlen($raw)<17)return null;$iv=substr($raw,0,16);$cipher=substr($raw,16);$key=hash('sha256',WF_ENCRYPTION_KEY,true);$plain=openssl_decrypt($cipher,'AES-256-CBC',$key,OPENSSL_RAW_DATA,$iv);return $plain===false?null:$plain;}
function wf_github_request($method,$path,$token,$body=null){$ch=curl_init('https://api.github.com'.$path);$headers=array('Accept: application/vnd.github+json','User-Agent: WolFox-AdminPanel','X-GitHub-Api-Version: 2022-11-28');if($token)$headers[]='Authorization: Bearer '.$token;curl_setopt($ch,CURLOPT_HTTPHEADER,$headers);curl_setopt($ch,CURLOPT_RETURNTRANSFER,true);curl_setopt($ch,CURLOPT_TIMEOUT,20);curl_setopt($ch,CURLOPT_CUSTOMREQUEST,$method);if($body!==null){curl_setopt($ch,CURLOPT_POSTFIELDS,json_encode($body));$headers[]='Content-Type: application/json';curl_setopt($ch,CURLOPT_HTTPHEADER,$headers);}$response=curl_exec($ch);$httpCode=curl_getinfo($ch,CURLINFO_HTTP_CODE);$error=curl_error($ch);curl_close($ch);if($error)return array('ok'=>false,'code'=>0,'message'=>$error,'data'=>null);$decoded=$response?json_decode($response,true):null;return array('ok'=>$httpCode>=200&&$httpCode<300,'code'=>$httpCode,'data'=>$decoded);}
db();
?>
