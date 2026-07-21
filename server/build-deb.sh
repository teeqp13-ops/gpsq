#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_DIR="$ROOT_DIR/server"
OUT_DIR="$ROOT_DIR/artifacts"
PKG_ROOT="$(mktemp -d)"
trap 'rm -rf "$PKG_ROOT"' EXIT

VERSION="${GPSQ_PANEL_VERSION:-1.0.0}"
ARCH="${GPSQ_PANEL_ARCH:-all}"
INSTALL_DIR="$PKG_ROOT/var/www/gpsq-panel"

mkdir -p "$PKG_ROOT/DEBIAN" "$INSTALL_DIR" "$OUT_DIR"
cp -R "$SERVER_DIR/public" "$INSTALL_DIR/"
cp "$SERVER_DIR/schema.sql" "$INSTALL_DIR/"
cp "$SERVER_DIR/README_AR.md" "$INSTALL_DIR/"

cat > "$PKG_ROOT/DEBIAN/control" <<EOF
Package: com.khalid.gpsq-panel
Name: GPSQ PHP Control Panel
Version: $VERSION
Architecture: $ARCH
Maintainer: Khalid
Section: web
Depends: php, php-sqlite3
Description: Arabic PHP control panel for GPSQ activation codes, devices, logs and settings.
EOF

cat > "$PKG_ROOT/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
mkdir -p /var/www/gpsq-panel
chmod -R 0755 /var/www/gpsq-panel
if [ ! -f /var/www/gpsq-panel/public/api/config.local.php ]; then
  cp /var/www/gpsq-panel/public/api/config.sample.php /var/www/gpsq-panel/public/api/config.local.php
  chmod 0600 /var/www/gpsq-panel/public/api/config.local.php
fi
exit 0
EOF
chmod 0755 "$PKG_ROOT/DEBIAN/postinst"

dpkg-deb --build --root-owner-group "$PKG_ROOT" "$OUT_DIR/gpsq-panel_${VERSION}_${ARCH}.deb"
sha256sum "$OUT_DIR/gpsq-panel_${VERSION}_${ARCH}.deb" > "$OUT_DIR/gpsq-panel_SHA256SUMS.txt"
