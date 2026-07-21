#!/usr/bin/env bash
set -Eeuo pipefail

trap 'echo "Build controller failed at line $LINENO: $BASH_COMMAND" >&2' ERR

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

: "${THEOS:?THEOS environment variable is required}"
[[ -d "$THEOS/makefiles" ]] || { echo "Invalid THEOS path: $THEOS" >&2; exit 1; }

MAX_BUILD_ATTEMPTS="${MAX_BUILD_ATTEMPTS:-5}"
RETRY_DELAY_SECONDS="${RETRY_DELAY_SECONDS:-5}"

[[ "$MAX_BUILD_ATTEMPTS" =~ ^[1-9][0-9]*$ ]] || { echo 'MAX_BUILD_ATTEMPTS must be a positive integer.' >&2; exit 2; }
[[ "$RETRY_DELAY_SECONDS" =~ ^[0-9]+$ ]] || { echo 'RETRY_DELAY_SECONDS must be a non-negative integer.' >&2; exit 2; }

SESSION_LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$SESSION_LOG_DIR"' EXIT

final_status=1
successful_attempt=0

for ((attempt=1; attempt<=MAX_BUILD_ATTEMPTS; attempt++)); do
  echo "=================================================="
  echo "Build attempt $attempt of $MAX_BUILD_ATTEMPTS"
  echo "=================================================="

  bash scripts/clean.sh
  mkdir -p artifacts

  validation_log="$SESSION_LOG_DIR/validation-attempt-$attempt.log"
  build_log="$SESSION_LOG_DIR/build-attempt-$attempt.log"

  set +e
  bash scripts/validate.sh 2>&1 | tee "$validation_log"
  validation_status=${PIPESTATUS[0]}
  set -e

  if (( validation_status != 0 )); then
    echo "Validation failed on attempt $attempt." >&2
    final_status=$validation_status
  else
    set +e
    make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless messages=yes -j1 2>&1 | tee "$build_log"
    build_status=${PIPESTATUS[0]}
    set -e

    if (( build_status == 0 )); then
      mapfile -t built_packages < <(find packages -type f -name '*.deb' -print)
      if (( ${#built_packages[@]} > 0 )); then
        for package in "${built_packages[@]}"; do
          cp -f "$package" artifacts/
        done
        mapfile -t copied_packages < <(find artifacts -maxdepth 1 -type f -name '*.deb' -print)
        sha256sum "${copied_packages[@]}" > artifacts/SHA256SUMS.txt
        successful_attempt=$attempt
        final_status=0
        cp "$validation_log" artifacts/
        cp "$build_log" artifacts/build.log
        break
      fi

      echo "Attempt $attempt completed without producing a DEB package." >&2
      final_status=3
    else
      echo "Build failed on attempt $attempt." >&2
      final_status=$build_status
      echo '========== DETECTED BUILD ERRORS ==========' >&2
      grep -nE 'error:|fatal error:|Undefined symbols|duplicate symbol|ld:|make\[[0-9]+\]: \*\*\*' "$build_log" >&2 || true
      echo '===========================================' >&2
    fi
  fi

  if (( attempt < MAX_BUILD_ATTEMPTS )); then
    echo "Cleaning and retrying after ${RETRY_DELAY_SECONDS}s..."
    sleep "$RETRY_DELAY_SECONDS"
  fi
done

mkdir -p artifacts
cp -f "$SESSION_LOG_DIR"/*.log artifacts/ 2>/dev/null || true

if (( final_status == 0 )); then
  printf 'status=success\nattempt=%s\nmax_attempts=%s\n' "$successful_attempt" "$MAX_BUILD_ATTEMPTS" > artifacts/BUILD_RESULT.txt
  echo "Build succeeded on attempt $successful_attempt of $MAX_BUILD_ATTEMPTS."
  ls -lah artifacts
  exit 0
fi

printf 'status=failed\nattempts=%s\nexit_code=%s\n' "$MAX_BUILD_ATTEMPTS" "$final_status" > artifacts/BUILD_RESULT.txt

echo "Build failed after $MAX_BUILD_ATTEMPTS attempts." >&2
echo "Final exit code: $final_status" >&2
ls -lah artifacts >&2
exit "$final_status"
