<?php
session_start();
require __DIR__ . '/../config.php';
require __DIR__ . '/_layout.php';
redirect_to_login();
$pdo=db();$msg='';$errorMsg='';
if(empty($_SESSION['csrf_token']))$_SESSION['csrf_token']=bin2hex(random_bytes(32));$csrf=$_SESSION['csrf_token'];
if($_SERVER['REQUEST_METHOD']==='POST'&&($_POST['action']??'')==='change_password'){
 if(!hash_equals($_SESSION['csrf_token']??'',$_POST['csrf_token']??''))$errorMsg='انتهت صلاحية الطلب، أعد تحميل الصفحة';
 else{$current=(string)($_POST['current_password']??'');$new=(string)($_POST['new_password']??'');$confirm=(string)($_POST['confirm_password']??'');
  if(!wf_verify_admin_password($current))$errorMsg='كلمة المرور الحالية غير صحيحة';
  elseif(strlen($new)<10)$errorMsg='كلمة المرور الجديدة يجب ألا تقل عن 10 خانات';
  elseif($new!==$confirm)$errorMsg='تأكيد كلمة المرور غير مطابق';
  else{wf_set_admin_password($new);session_regenerate_id(true);$msg='تم تغيير كلمة المرور بنجاح';}
 }
}
$notifications=wf_notifications($pdo);
?>
<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>WolFox - الإعدادات</title><link rel="stylesheet" href="style.css"><link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css"><link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;800&display=swap" rel="stylesheet"></head><body><?php wf_sidebar('settings');?><main class="main-content"><?php wf_topbar('الإعدادات','إدارة أمان اللوحة وهوية النظام.',$notifications);?><?php if($msg):?><div class="alert-box alert-success"><i class="fas fa-circle-check"></i><?php echo htmlspecialchars($msg);?></div><?php endif;?><?php if($errorMsg):?><div class="alert-box alert-danger"><i class="fas fa-triangle-exclamation"></i><?php echo htmlspecialchars($errorMsg);?></div><?php endif;?><div class="settings-grid"><section class="panel"><div class="panel-title"><i class="fas fa-lock"></i> تغيير كلمة مرور الإدارة</div><form method="POST" class="form-stack" autocomplete="off"><input type="hidden" name="action" value="change_password"><input type="hidden" name="csrf_token" value="<?php echo htmlspecialchars($csrf);?>"><label>كلمة المرور الحالية<input class="input-control" type="password" name="current_password" required></label><label>كلمة المرور الجديدة<input class="input-control" type="password" name="new_password" minlength="10" required></label><label>تأكيد كلمة المرور<input class="input-control" type="password" name="confirm_password" minlength="10" required></label><button class="btn btn-primary" type="submit"><i class="fas fa-key"></i> حفظ كلمة المرور</button></form></section><section class="panel"><div class="panel-title"><i class="fas fa-shield-halved"></i> حالة الحماية</div><div class="security-list"><div><i class="fas fa-circle-check"></i><span><strong>تخزين مشفّر</strong><small>لا تُحفظ كلمة المرور كنص واضح.</small></span></div><div><i class="fas fa-circle-check"></i><span><strong>جلسة آمنة</strong><small>يتغير معرف الجلسة بعد الدخول والتحديث.</small></span></div><div><i class="fas fa-circle-check"></i><span><strong>حماية الطلب</strong><small>تغيير كلمة المرور محمي برمز CSRF.</small></span></div></div></section></div></main><div id="toast" class="toast"></div><script src="app.js"></script></body></html>
