#!/usr/bin/env bash
set -euo pipefail

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
)

for file in "${required[@]}"; do
  [[ -f "$file" ]] || { echo "Missing required file: $file" >&2; exit 1; }
done

grep -q 'TWEAK_NAME := gpsq FakeGPSLocation' Makefile
grep -q 'gpsq_FILES := FakeGPS.mm SharedBridge.xm FeaturePack.xm' Makefile
grep -q 'FakeGPSLocation_FILES := LocationSpoof.xm' Makefile
grep -q 'Package: com.khalid.fakegps' control
grep -q 'Version: 2.0.1' control
grep -q 'com.apple.springboard' gpsq.plist
grep -q 'CLLocationManager' FakeGPSLocation.plist
grep -q 'FGLicenseIsActive' FeaturePack.xm
grep -q 'api/activate.php' FeaturePack.xm

python3 -m json.tool Resources/defaults.json >/dev/null
plutil -lint Resources/Info.plist >/dev/null 2>&1 || true

if git ls-files | grep -E '(^|/)(\.theos|obj|packages|artifacts|build)(/|$)|\.(deb|dylib|o|log|tmp)$'; then
  echo 'Generated files are tracked. Remove them before building.' >&2
  exit 1
fi

echo 'Repository validation passed.'
