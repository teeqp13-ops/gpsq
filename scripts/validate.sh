#!/usr/bin/env bash
set -Eeuo pipefail

trap 'echo "Validation failed at line $LINENO: $BASH_COMMAND" >&2' ERR

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
  [[ -s "$file" ]] || { echo "Required file is empty: $file" >&2; exit 1; }
done

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
plutil -lint Resources/Info.plist >/dev/null
plutil -lint gpsq.plist >/dev/null
plutil -lint FakeGPSLocation.plist >/dev/null

if git ls-files | grep -Eq '(^|/)(\.theos|obj|packages|artifacts|build|DerivedData)(/|$)|\.(deb|dylib|o|log|tmp|swp)$'; then
  echo 'Generated files are tracked. Remove them before building.' >&2
  exit 1
fi

if git grep -nE '(api[_-]?key|secret|password|token)[[:space:]]*=[[:space:]]*["'"'][^"'"']+["'"']' -- ':!scripts/validate.sh' ':!Resources/defaults.json'; then
  echo 'Possible hard-coded secret detected.' >&2
  exit 1
fi

echo 'Repository validation passed.'
