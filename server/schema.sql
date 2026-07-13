-- GPS Plus — مخطط قاعدة البيانات
-- يمكن تشغيل هذا الملف يدوياً بـ: sqlite3 gpsq.db < server/schema.sql
-- لاستخدام MySQL: عدّل نوع البيانات (TEXT → VARCHAR، INTEGER → INT، datetime() → NOW())

-- ================================================================
-- جدول الأكواد الرئيسي
-- ================================================================
CREATE TABLE IF NOT EXISTS codes (
    code         TEXT PRIMARY KEY,                 -- كود التفعيل (8+ خانات)
    status       TEXT NOT NULL DEFAULT 'unused',   -- unused | linked | expired | closed
    udid         TEXT,                             -- معرّف الجهاز الأول المرتبط
    device_name  TEXT,                             -- اسم الجهاز المرتبط
    ios_version  TEXT,                             -- إصدار iOS عند التفعيل
    app_version  TEXT,                             -- إصدار التطبيق عند التفعيل
    created_at   TEXT NOT NULL DEFAULT (datetime('now')),  -- تاريخ إنشاء الكود
    activated_at TEXT                              -- تاريخ أول تفعيل
);

-- ================================================================
-- جدول الأجهزة — لدعم تتبع أجهزة متعددة لكل كود مستقبلاً
-- ================================================================
CREATE TABLE IF NOT EXISTS devices (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    code        TEXT NOT NULL,
    udid        TEXT NOT NULL,
    device_name TEXT,
    ios_version TEXT,
    app_version TEXT,
    first_seen  TEXT NOT NULL DEFAULT (datetime('now')),
    last_seen   TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(code, udid)
);

-- ================================================================
-- جدول نبضات الحياة — للتتبع الدوري (heartbeat)
-- ================================================================
CREATE TABLE IF NOT EXISTS heartbeats (
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL,
    udid TEXT NOT NULL,
    ts   TEXT NOT NULL DEFAULT (datetime('now'))
);

-- فهارس لتحسين الأداء عند البحث
CREATE INDEX IF NOT EXISTS idx_codes_status     ON codes (status);
CREATE INDEX IF NOT EXISTS idx_devices_code     ON devices (code);
CREATE INDEX IF NOT EXISTS idx_heartbeats_code  ON heartbeats (code, udid);
