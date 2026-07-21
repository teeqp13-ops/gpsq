#!/bin/sh
set -e
TARGET="/var/mobile/Library/Preferences/com.byano.activation.plist"
SAMPLE="/Library/Application Support/BYANOActivation/ExternalLicense.sample.plist"

if [ ! -f "$TARGET" ] && [ -f "$SAMPLE" ]; then
    cp "$SAMPLE" "$TARGET"
    chown mobile:mobile "$TARGET" 2>/dev/null || true
    chmod 600 "$TARGET"
fi
