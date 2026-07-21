# BYANO — تفعيل مستقل من ملف خارجي

هذا التكامل لا يقرأ ولا يكتب أي مفتاح تابع لـ GPS PLUS.

## ملف التفعيل

المسار الأساسي:

```text
/var/mobile/Library/Preferences/com.byano.activation.plist
```

ومسار Rootless:

```text
/var/jb/var/mobile/Library/Preferences/com.byano.activation.plist
```

المفاتيح المستخدمة:

```text
activation_code
access_token
expires_at
device_uuid
activation_active
```

يتم التحقق عبر:

```text
https://key.p3nd.fun/api/activate.php
```

للبناء:

```bash
cd integrations/byano-independent
bash build.sh
```
