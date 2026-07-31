# GPSQ Activation — Objective-C++

واجهة iOS فعلية بامتداد `.mm` مبنية بـ UIKit ومتصلة بنظام التفعيل على:

- `POST https://mm.p3nd.fun/api/activate.php`
- `POST https://mm.p3nd.fun/api/verify.php`

## التدفق
1. تظهر شاشة التفعيل عند تشغيل التطبيق.
2. يقبل الحقل كودًا رقميًا من 8 إلى 20 رقمًا.
3. يرسل التطبيق `project_key=gpsq` والكود ومعرف الجهاز إلى الخادم.
4. عند النجاح يُحفظ رمز الجلسة في Keychain.
5. عند التشغيل التالي يتم التحقق من الجلسة قبل عرض شاشة المميزات.
6. عند انتهاء أو إيقاف الترخيص تعود شاشة إدخال الكود.

## الملفات
- `Sources/GPSQActivation.mm`: الواجهة والربط الكامل.
- `GPSQActivation.plist`: فلتر التطبيق المستهدف.
- `Makefile`: إعداد بناء Theos.
- `control`: بيانات حزمة DEB.

## إشعارات التكامل
عند نجاح التفعيل:

```objc
GPSQActivationCompleted
```

وعند اختيار موقع من الخريطة:

```objc
GPSQChooseLocation
```

بيانات الموقع موجودة داخل `userInfo` بالمفاتيح `latitude` و`longitude`.

## البناء

```bash
cd integrations/gpsq-activation
make clean package FINALPACKAGE=1
```

الناتج سيكون ملف DEB ومكتبة `GPSQActivation.dylib`.
