# GPS Plus Server Panel

هذه نسخة السيرفر واللوحة المطلوبة لمشروع gpsq.

## الربط المعتمد

API Base:

```text
https://ipa.p3nd.fun/server/public/api
```

مفتاح API لا يُكتب داخل المستودع. ضعه في GitHub Secrets باسم:

```text
GPSQ_API_KEY
```

## المطلوب في اللوحة

- أزرار نسخ للأكواد ومفتاح API.
- تمييز حالة الكود: غير مستخدم، مرتبط، منتهي، مغلق.
- عرض الأجهزة المرتبطة بكل كود.
- فلاتر للأكواد غير المستخدمة والمرتبطة.
- صفحة إحصائيات للأكواد التي تم تثبيتها.
- صفحة خارجية للعميل باسم `redeem.php` للتحقق من الكود بدون دخول لوحة الإدارة.

## صفحات السيرفر

```text
public/index.php          — لوحة التحكم (تسجيل دخول بكلمة مرور)
public/redeem.php         — صفحة عامة للتحقق من كود التفعيل
public/api/config.php     — إعدادات مشتركة (قاعدة البيانات، مفتاح API)
public/api/activate.php   — نقطة نهاية تفعيل الكود (POST)
public/api/heartbeat.php  — نقطة نهاية نبضة الحياة (POST)
```

## الإعداد المحلي (تشغيل السيرفر)

### 1. إعداد متغيرات البيئة

```bash
# تعيين مفتاح API وكلمة مرور الإدارة في البيئة الحالية
export GPSQ_API_KEY="ضع-مفتاح-API-هنا"
export GPSQ_ADMIN_PASSWORD="ضع-كلمة-مرور-قوية-هنا"
```

أو انسخ ملف الإعدادات النموذجي وعدّله:

```bash
cp server/public/api/config.sample.php server/public/api/config.local.php
# ثم افتح config.local.php وعدّل القيم
```

> ⚠️ لا تضف `config.local.php` أو `*.db` إلى git — هي مضافة إلى `.gitignore` تلقائياً.

### 2. تشغيل السيرفر المدمج في PHP

```bash
php -S localhost:8000 -t server/public
```

ثم افتح المتصفح على:

- `http://localhost:8000/` — لوحة التحكم
- `http://localhost:8000/redeem.php` — التحقق من كود

### 3. تهيئة قاعدة البيانات (اختياري)

قاعدة البيانات SQLite تُنشأ تلقائياً عند أول طلب. لتهيئتها يدوياً:

```bash
sqlite3 gpsq.db < server/schema.sql
```

### 4. النشر على سيرفر (Nginx/Apache)

- اضبط `DocumentRoot` على مجلد `server/public/`
- تأكد من تعيين متغيرات البيئة `GPSQ_API_KEY` و `GPSQ_ADMIN_PASSWORD` في إعدادات الخادم.
- للتبديل إلى MySQL: راجع التعليقات في `server/public/api/config.php`.
