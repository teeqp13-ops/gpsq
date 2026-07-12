<?php
declare(strict_types=1); $config=require dirname(__DIR__).'/app/config.php';
if(file_exists($config['install_lock'])){http_response_code(403);exit('تم التثبيت مسبقًا.');}
require dirname(__DIR__).'/app/bootstrap.php'; file_put_contents($config['install_lock'],date(DATE_ATOM),LOCK_EX); @chmod($config['install_lock'],0600);
?><!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="assets/style.css"><title>التثبيت</title></head><body><main class="page"><section class="card"><h1>تم التثبيت بنجاح</h1><p>تم إنشاء قاعدة البيانات وقفل صفحة التثبيت تلقائيًا.</p><div class="result success"><strong>اسم المستخدم:</strong> admin<br><strong>كلمة المرور المؤقتة:</strong> 123456</div><p>غيّر كلمة المرور مباشرة بعد أول تسجيل دخول.</p><a class="btn" href="admin/login.php">دخول الإدارة</a></section></main></body></html>
