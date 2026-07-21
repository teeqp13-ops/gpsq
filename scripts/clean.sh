#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

KEEP_ARTIFACTS="${KEEP_ARTIFACTS:-0}"

rm -rf .theos obj packages build DerivedData
if [[ "$KEEP_ARTIFACTS" != "1" ]]; then
  rm -rf artifacts
fi

find . -type f \
  ! -path './artifacts/*' \
  \( -name '*.deb' -o -name '*.dylib' -o -name '*.o' -o -name '*.log' -o -name '*.tmp' -o -name '*.swp' -o -name '.DS_Store' \) \
  -delete

echo 'Repository build files cleaned.'
