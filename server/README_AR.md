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
public/index.php
public/redeem.php
public/api/config.php
public/api/activate.php
public/api/heartbeat.php
```
