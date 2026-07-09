# gpsq

مشروع Theos نظيف لبناء أداة **gpsq / GPS Plus v1.1**.

## الملفات المعتمدة

```text
gpsq.mm
Makefile
control
.github/workflows/build.yml
.gitignore
README.md
```

## المميزات

- ملف مصدر واحد فقط: `gpsq.mm`.
- واجهة عربية داكنة.
- إدخال كود تفعيل من 8 خانات.
- استخراج UDID/UUID تلقائيًا.
- دعم iOS 16 وأحدث.
- خرائط: خريطة / قمر صناعي / هجينة.
- بحث بالموقع أو الإحداثيات.
- GitHub Actions للبناء ورفع ملفات `.deb` كـ Artifacts.

## البناء محليًا

```bash
make clean
make package FINALPACKAGE=1
```

## البناء عبر GitHub Actions

افتح تبويب **Actions** ثم شغّل workflow باسم:

```text
Build gpsq
```

بعد اكتمال البناء ستجد الناتج داخل Artifacts باسم:

```text
gpsq-DEB-Packages
```

## بيانات التفعيل

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
