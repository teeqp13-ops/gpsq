#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

rm -rf .theos obj packages artifacts build DerivedData
find . -type f \( -name '*.deb' -o -name '*.dylib' -o -name '*.o' -o -name '*.log' -o -name '*.tmp' -o -name '*.swp' -o -name '.DS_Store' \) -delete

echo 'Repository build files cleaned.'
