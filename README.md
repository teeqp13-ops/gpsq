# gpsq

مشروع Theos نظيف لبناء أداة **gpsq / GPS Plus v1.1**.

## المميزات

- ملف مصدر واحد فقط: `gpsq.mm`
- واجهة عربية داكنة
- إدخال كود تفعيل من 8 خانات
- استخراج UDID/UUID تلقائيًا
- دعم iOS 16 وأحدث
- خرائط: خريطة / قمر صناعي / هجينة
- بحث بالموقع أو الإحداثيات
- GitHub Actions للبناء ورفع ملفات `.deb` كـ Artifacts

## الملفات

```text
gpsq.mm
Makefile
control
.github/workflows/build.yml
.gitignore
README.md
```

## البناء محليًا

```bash
make clean
make package FINALPACKAGE=1
```

## البناء عبر GitHub Actions

ادخل تبويب **Actions** ثم شغّل workflow باسم **Build gpsq Tweak**. بعد اكتمال البناء ستجد ملف `.deb` داخل Artifacts باسم:

```text
gpsq-DEB-Packages
```

## إعدادات مهمة

رابط التفعيل داخل `gpsq.mm`:

```objc
#define GPSQ_ACTIVATION_URL @"https://p3nd.fun/gps/api/activate.php"
```

البيانات المرسلة للسيرفر:

```text
code
udid
ios_version
app_version
```
