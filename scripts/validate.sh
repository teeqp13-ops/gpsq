#!/usr/bin/env bash
set -Eeuo pipefail

trap 'echo "Validation failed at line $LINENO: $BASH_COMMAND" >&2' ERR

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

required=(
  Makefile
  control
  FakeGPS.mm
  SharedBridge.xm
  FeaturePack.xm
  LocationSpoof.xm
  gpsq.plist
  FakeGPSLocation.plist
  Resources/Info.plist
  Resources/defaults.json
  Resources/ar.lproj/Localizable.strings
  scripts/clean.sh
  scripts/build.sh
)

for file in "${required[@]}"; do
  [[ -f "$file" ]] || { echo "Missing required file: $file" >&2; exit 1; }
  [[ -s "$file" ]] || { echo "Required file is empty: $file" >&2; exit 1; }
done

# Validate shell syntax before executing any project command.
bash -n scripts/validate.sh
bash -n scripts/clean.sh
bash -n scripts/build.sh

grep -Fq 'TWEAK_NAME := gpsq FakeGPSLocation' Makefile
grep -Fq 'gpsq_FILES := FakeGPS.mm SharedBridge.xm FeaturePack.xm' Makefile
grep -Fq 'FakeGPSLocation_FILES := LocationSpoof.xm' Makefile
grep -Fq 'Package: com.khalid.fakegps' control
grep -Eq '^Version: [0-9]+\.[0-9]+\.[0-9]+$' control
grep -Fq 'com.apple.springboard' gpsq.plist
grep -Fq 'CLLocationManager' FakeGPSLocation.plist
grep -Fq 'FGLicenseIsActive' FeaturePack.xm
grep -Fq 'https://key.p3nd.fun/api/activate.php' FeaturePack.xm

python3 -m json.tool Resources/defaults.json >/dev/null
python3 - <<'PY'
import plistlib
from pathlib import Path

path = Path('Resources/Info.plist')
with path.open('rb') as handle:
    value = plistlib.load(handle)
if not isinstance(value, dict):
    raise SystemExit('Resources/Info.plist must contain a dictionary')
required = {'CFBundleIdentifier', 'CFBundleName', 'CFBundleShortVersionString', 'CFBundleVersion'}
missing = sorted(required.difference(value))
if missing:
    raise SystemExit(f"Resources/Info.plist missing keys: {', '.join(missing)}")
PY

# Theos filter plists use OpenStep syntax, so validate their required structure
# without passing them to Linux plutil, which only reliably handles XML/binary plists.
grep -Eq 'Filter[[:space:]]*=' gpsq.plist
grep -Eq 'Bundles[[:space:]]*=' gpsq.plist
grep -Eq 'Filter[[:space:]]*=' FakeGPSLocation.plist

auto_generated_pattern='(^|/)(\.theos|obj|packages|artifacts|build|DerivedData)(/|$)|\.(deb|dylib|o|log|tmp|swp)$'
if git ls-files | grep -Eq "$auto_generated_pattern"; then
  echo 'Generated files are tracked. Remove them before building.' >&2
  exit 1
fi

# Scan common assignment styles while excluding known non-secret references.
if git grep -nEi '(api[_-]?key|secret|password)[[:space:]]*[:=][[:space:]]*[^[:space:]]+' -- \
  ':!scripts/validate.sh' \
  ':!Resources/defaults.json'; then
  echo 'Possible hard-coded secret detected.' >&2
  exit 1
fi

echo 'Repository validation passed.'
