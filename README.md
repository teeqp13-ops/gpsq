# gpsq

مشروع Theos منظم بنظام Framework لبناء أداة **gpsq / GPS Plus v1.1**.

## الهيكل

```text
gpsq.mm
Makefile
control
.github/workflows/build.yml
.gitignore
README.md
Headers/
Core/
UI/
Map/
Utils/
Resources/
```

## المجلدات

- `Headers`: التعريفات والإعدادات العامة.
- `Core`: إدارة التفعيل، UUID، الشبكة، التخزين، والمدير العام.
- `UI`: ملفات الواجهة والمكونات.
- `Map`: الخريطة، البحث، والمفضلة.
- `Utils`: أدوات مساعدة مثل Logger.
- `Resources`: ملفات اللغة والصور لاحقًا.

## المميزات

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

رابط التفعيل داخل `Headers/GPSQConfig.h` وداخل `gpsq.mm`:

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
