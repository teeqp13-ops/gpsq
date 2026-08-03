# WolfGPS Pro V15 — النسخة المدمجة

تم الحفاظ على ملفات V14 الأصلية ودمج واجهة WFGPSPanel الجديدة، مع إضافة بنية مستقلة قابلة للصيانة:

- `WFThemeManager`: وضع فاتح/داكن وتأثيرات Glass.
- `WFLocalization`: العربية والإنجليزية مع حفظ الاختيار.
- `WFFavoritesViewController`: عرض المفضلة واختيارها وتعديل الاسم وحذف العنصر.
- `WFGPXMovementManager`: قراءة ملفات GPX، بدء/إيقاف الحركة، وسرعات متعددة.
- `WFGPSFloatingButton`: زر مغناطيسي يلتصق بحافتي الشاشة ويحفظ موضعه.
- تحديث `WFGPSFavoritesManager` لإضافة التعديل الدائم بجانب الحفظ والحذف.

## ملاحظة الدمج

ملف الواجهة الذي رفعه المستخدم أصبح `Source/WFGPSPanel.mm`، والنسخة الاحتياطية منه محفوظة في `Source/WFGPSPanel.mm.bak`.

## البناء

```bash
make clean package FINALPACKAGE=1
```
