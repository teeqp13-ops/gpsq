#!/usr/bin/env bash
set -Eeuo pipefail

: "${THEOS:?THEOS is required}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

rm -rf .theos obj packages artifacts
mkdir -p artifacts/dylibs artifacts/logs

BUILD_LOG="artifacts/logs/build.log"

set +e
make clean package \
  FINALPACKAGE=1 \
  THEOS_PACKAGE_SCHEME=rootless \
  messages=yes \
  -j1 2>&1 | tee "$BUILD_LOG"
status=${PIPESTATUS[0]}
set -e

if [ "$status" -ne 0 ]; then
  echo "Build failed. Important errors:" >&2
  grep -nE 'error:|fatal error:|Undefined symbols|duplicate symbol|ld:|make.*\*\*\*' "$BUILD_LOG" >&2 || true
  exit "$status"
fi

find packages -type f -name '*.deb' -exec cp -f {} artifacts/ \;
find .theos -type f -name '*.dylib' -exec cp -f {} artifacts/dylibs/ \;

test -n "$(find artifacts -maxdepth 1 -type f -name '*.deb' -print -quit)"
test -n "$(find artifacts/dylibs -type f -name '*.dylib' -print -quit)"

find artifacts -type f \( -name '*.deb' -o -name '*.dylib' \) -print0 \
  | sort -z \
  | xargs -0 sha256sum > artifacts/SHA256SUMS.txt

printf 'status=success\napi=https://key.p3nd.fun/api/activate.php\n' > artifacts/BUILD_RESULT.txt
find artifacts -maxdepth 2 -type f -print
