#!/usr/bin/env bash
set -Eeuo pipefail

trap 'echo "Build controller failed at line $LINENO: $BASH_COMMAND" >&2' ERR

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

: "${THEOS:?THEOS environment variable is required}"
[[ -d "$THEOS/makefiles" ]] || { echo "Invalid THEOS path: $THEOS" >&2; exit 1; }

MAX_BUILD_ATTEMPTS="${MAX_BUILD_ATTEMPTS:-3}"
RETRY_DELAY_SECONDS="${RETRY_DELAY_SECONDS:-3}"
[[ "$MAX_BUILD_ATTEMPTS" =~ ^[1-9][0-9]*$ ]] || exit 2
[[ "$RETRY_DELAY_SECONDS" =~ ^[0-9]+$ ]] || exit 2

SESSION_LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$SESSION_LOG_DIR"' EXIT

rm -rf artifacts
mkdir -p artifacts/dylibs
final_status=1
successful_attempt=0

for ((attempt=1; attempt<=MAX_BUILD_ATTEMPTS; attempt++)); do
  echo "=== Build attempt $attempt/$MAX_BUILD_ATTEMPTS ==="
  KEEP_ARTIFACTS=1 bash scripts/clean.sh
  mkdir -p artifacts/dylibs

  validation_log="$SESSION_LOG_DIR/validation-attempt-$attempt.log"
  build_log="$SESSION_LOG_DIR/build-attempt-$attempt.log"

  set +e
  bash scripts/validate.sh 2>&1 | tee "$validation_log"
  validation_status=${PIPESTATUS[0]}
  set -e

  if (( validation_status != 0 )); then
    final_status=$validation_status
  else
    set +e
    make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless messages=yes -j1 2>&1 | tee "$build_log"
    build_status=${PIPESTATUS[0]}
    set -e

    if (( build_status == 0 )); then
      mapfile -t built_packages < <(find packages -type f -name '*.deb' -print)
      mapfile -t built_dylibs < <(find .theos -type f -name '*.dylib' -print)

      if (( ${#built_packages[@]} > 0 && ${#built_dylibs[@]} > 0 )); then
        for package in "${built_packages[@]}"; do cp -f "$package" artifacts/; done
        for dylib in "${built_dylibs[@]}"; do cp -f "$dylib" artifacts/dylibs/; done

        mapfile -t copied_packages < <(find artifacts -maxdepth 1 -type f -name '*.deb' -print)
        mapfile -t copied_dylibs < <(find artifacts/dylibs -maxdepth 1 -type f -name '*.dylib' -print)
        sha256sum "${copied_packages[@]}" "${copied_dylibs[@]}" > artifacts/SHA256SUMS.txt
        cp "$validation_log" artifacts/
        cp "$build_log" artifacts/build.log
        successful_attempt=$attempt
        final_status=0
        break
      fi

      echo 'Build finished but no DEB or dylib output was found.' >&2
      find .theos packages -maxdepth 6 -type f -print 2>/dev/null >&2 || true
      final_status=3
    else
      final_status=$build_status
      grep -nE 'error:|fatal error:|Undefined symbols|duplicate symbol|ld:|make\[[0-9]+\]: \*\*\*' "$build_log" >&2 || true
    fi
  fi

  if (( attempt < MAX_BUILD_ATTEMPTS )); then sleep "$RETRY_DELAY_SECONDS"; fi
done

mkdir -p artifacts
cp -f "$SESSION_LOG_DIR"/*.log artifacts/ 2>/dev/null || true

if (( final_status == 0 )); then
  printf 'status=success\nattempt=%s\n' "$successful_attempt" > artifacts/BUILD_RESULT.txt
  find artifacts -maxdepth 2 -type f -print
  exit 0
fi

printf 'status=failed\nattempts=%s\nexit_code=%s\n' "$MAX_BUILD_ATTEMPTS" "$final_status" > artifacts/BUILD_RESULT.txt
find artifacts -maxdepth 2 -type f -print >&2 || true
exit "$final_status"
