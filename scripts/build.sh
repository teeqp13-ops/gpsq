#!/usr/bin/env bash
set -Eeuo pipefail

trap 'echo "Build failed at line $LINENO: $BASH_COMMAND" >&2' ERR

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

: "${THEOS:?THEOS environment variable is required}"
[[ -d "$THEOS/makefiles" ]] || { echo "Invalid THEOS path: $THEOS" >&2; exit 1; }

bash scripts/clean.sh
bash scripts/validate.sh
mkdir -p artifacts

set +e
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless messages=yes -j1 2>&1 | tee artifacts/build.log
status=${PIPESTATUS[0]}
set -e

if (( status != 0 )); then
  echo '========== BUILD ERRORS ==========' >&2
  grep -nE 'error:|fatal error:|Undefined symbols|duplicate symbol|ld:|make\[[0-9]+\]: \*\*\*' artifacts/build.log >&2 || true
  echo '==================================' >&2
  exit "$status"
fi

find packages -type f -name '*.deb' -exec cp -f {} artifacts/ \;
mapfile -t packages_found < <(find artifacts -maxdepth 1 -type f -name '*.deb' -print)
(( ${#packages_found[@]} > 0 )) || { echo 'Build completed without a DEB package.' >&2; exit 1; }

sha256sum "${packages_found[@]}" > artifacts/SHA256SUMS.txt
ls -lah artifacts
