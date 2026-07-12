# GPSPlus Server

تم دمج نواة السيرفر من ملف `GPSPlus_SERVER_FIXED.zip`.

## المسارات

- `public/install.php` تثبيت قاعدة البيانات مرة واحدة.
- `public/health.php` فحص PHP وSQLite وصلاحيات التخزين.
- `public/api/activate.php` تفعيل وربط الكود بالجهاز والسورس.
- `public/api/check.php` فحص الاشتراك.
- `public/api/status.php` حالة الاشتراك.
- `public/api/heartbeat.php` تحديث آخر اتصال.

## الإعداد

اضبط متغير البيئة `GPS_API_KEY` على نفس القيمة المستخدمة أثناء بناء أداة gpsq، ثم ارفع مجلد `server` مع إبقاء `storage` قابلًا للكتابة وغير مكشوف للويب.
