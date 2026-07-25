PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS codes (
    code TEXT PRIMARY KEY,
    status TEXT NOT NULL DEFAULT 'unused',
    udid TEXT,
    device_name TEXT,
    ios_version TEXT,
    app_version TEXT,
    duration_days INTEGER NOT NULL DEFAULT 30,
    max_devices INTEGER NOT NULL DEFAULT 1,
    note TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    activated_at TEXT,
    expires_at TEXT
);

CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL,
    udid TEXT NOT NULL,
    device_name TEXT,
    ios_version TEXT,
    app_version TEXT,
    first_seen TEXT NOT NULL DEFAULT (datetime('now')),
    last_seen TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(code, udid),
    FOREIGN KEY(code) REFERENCES codes(code) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS activity_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT,
    udid TEXT,
    action TEXT NOT NULL,
    result TEXT NOT NULL,
    message TEXT,
    ip TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS settings (
    name TEXT PRIMARY KEY,
    value TEXT,
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO settings(name,value) VALUES
('maintenance','0'),
('force_update','0'),
('minimum_version','1.0'),
('server_message','');

CREATE INDEX IF NOT EXISTS idx_codes_status ON codes(status);
CREATE INDEX IF NOT EXISTS idx_codes_expiry ON codes(expires_at);
CREATE INDEX IF NOT EXISTS idx_devices_code ON devices(code);
CREATE INDEX IF NOT EXISTS idx_logs_code ON activity_logs(code, created_at);
