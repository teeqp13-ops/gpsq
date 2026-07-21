#!/usr/bin/env bash
set -Eeuo pipefail
: "${THEOS:?THEOS is required}"
rm -rf .theos obj packages artifacts
mkdir -p artifacts/dylibs
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless -j1
find packages -type f -name '*.deb' -exec cp -f {} artifacts/ \;
find .theos -type f -name '*.dylib' -exec cp -f {} artifacts/dylibs/ \;
test -n "$(find artifacts -maxdepth 1 -type f -name '*.deb' -print -quit)"
test -n "$(find artifacts/dylibs -type f -name '*.dylib' -print -quit)"
find artifacts -type f \( -name '*.deb' -o -name '*.dylib' \) -print0 | sort -z | xargs -0 sha256sum > artifacts/SHA256SUMS.txt
