<?php
session_start();
require __DIR__ . '/../config.php';
$msg='';
if($_SERVER['REQUEST_METHOD']==='POST'){
 $password=$_POST['password']??'';
 if(wf_verify_admin_password($password)){session_regenerate_id(true);$_SESSION['wf_admin']=true;header('Location: dashboard.php');exit;}
 $msg='كلمة المرور غير صحيحة';
}
if(is_admin()){header('Location: dashboard.php');exit;}
?>
<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>WolFox - تسجيل الدخول</title><link rel="stylesheet" href="style.css"><link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css"><link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;800&display=swap" rel="stylesheet"></head><body class="login-page"><div class="login-card"><div class="logo"><i class="fas fa-shield-halved"></i><span>WolFox</span></div><h2>لوحة التحكم الشاملة</h2><?php if($msg):?><div class="alert-box alert-danger"><i class="fas fa-triangle-exclamation"></i><?php echo htmlspecialchars($msg);?></div><?php endif;?><form method="POST" class="form-stack"><label>كلمة المرور<input class="input-control" type="password" name="password" required autofocus></label><button type="submit" class="btn btn-primary"><i class="fas fa-right-to-bracket"></i>دخول آمن</button></form></div></body></html>
