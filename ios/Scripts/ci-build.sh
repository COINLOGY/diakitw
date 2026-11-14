#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$PWD/out"
mkdir -p "$OUT/evidence"
[[ -d "${DEVELOPER_DIR:?Workflow must pin Xcode}" ]]
xcodebuild -version | tee "$OUT/evidence/toolchain.txt"
xcrun --sdk iphoneos --show-sdk-version | tee -a "$OUT/evidence/toolchain.txt"
xcrun --sdk iphonesimulator --show-sdk-version | tee -a "$OUT/evidence/toolchain.txt"
swift --version | tee -a "$OUT/evidence/toolchain.txt"
python3 Tests/test_expressive.py | tee "$OUT/evidence/presentation.log"
python3 Tests/test_speed_contract.py | tee "$OUT/evidence/speed-contract.log"
swiftc -j 2 -parse-as-library Sources/UpdateChecker.swift Tests/update_checks.swift -o "$OUT/update-checks"
"$OUT/update-checks" | tee "$OUT/evidence/update-checks.log"
bash test.sh 2>&1 | tee "$OUT/evidence/host-tests.log"
COMMON=(-project diakitw.xcodeproj -scheme diakitw -jobs 2 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 'OTHER_SWIFT_FLAGS=$(inherited) -j2')
xcodebuild "${COMMON[@]}" -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath "$RUNNER_TEMP/device" build 2>&1 | tee "$OUT/evidence/device-build.log"
DEVICE="$RUNNER_TEMP/device/Build/Products/Release-iphoneos/diakitw.app"
file "$DEVICE/diakitw" | tee "$OUT/evidence/device-macho.txt"
plutil -p "$DEVICE/Info.plist" > "$OUT/evidence/device-plist.txt"
if codesign -dv "$DEVICE" 2> "$OUT/evidence/device-signature.txt"; then exit 1; fi
ditto -c -k --keepParent "$DEVICE" "$OUT/diakitw-0.5.5-ios-UNSIGNED-device.app.zip"
xcodebuild "${COMMON[@]}" -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath "$RUNNER_TEMP/simulator" build 2>&1 | tee "$OUT/evidence/simulator-build.log"
ditto -c -k --keepParent "$RUNNER_TEMP/simulator/Build/Products/Release-iphonesimulator/diakitw.app" "$OUT/diakitw-0.5.5-ios-simulator.app.zip"
xcrun simctl list devices available -j > "$OUT/evidence/simulators.json"
UDID=$(python3 - "$OUT/evidence/simulators.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
for runtime,devices in j['devices'].items():
 if 'iOS' in runtime:
  for d in devices:
   if d['name'].startswith('iPhone'):
    print(d['udid']); sys.exit(0)
raise SystemExit('No preinstalled iPhone runtime')
PY
)
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcodebuild "${COMMON[@]}" -configuration Debug -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$RUNNER_TEMP/tests" -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -resultBundlePath "$OUT/evidence/CoreTests.xcresult" test 2>&1 | tee "$OUT/evidence/simulator-tests.log"
python3 Scripts/fixture_copy.py "$RUNNER_TEMP/fixture-ios"
(cd "$RUNNER_TEMP/fixture-ios"; xcodebuild "${COMMON[@]}" -configuration Release -sdk iphonesimulator -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$RUNNER_TEMP/fixture-build" build) 2>&1 | tee "$OUT/evidence/fixture-build.log"
xcrun simctl install "$UDID" "$RUNNER_TEMP/fixture-build/Build/Products/Release-iphonesimulator/diakitw.app"
for MODE in present unknown; do
 SIMCTL_CHILD_DIAKITW_FIXTURE="$MODE" xcrun simctl launch "$UDID" app.diakitw.ios | tee "$OUT/evidence/launch-$MODE.txt"
 sleep 5
 xcrun simctl io "$UDID" screenshot "$OUT/evidence/simulator-$MODE.png"
 xcrun simctl terminate "$UDID" app.diakitw.ios
 done
xcrun simctl shutdown "$UDID"
git -C .. archive --format=zip HEAD ios LICENSE NOTICE .github/workflows/ios-build.yml > "$OUT/diakitw-0.5.5-ios-SOURCE.zip"
(cd "$OUT"; shasum -a 256 *.zip > SHA256SUMS.txt)
printf 'PASS: two cold launches of test-only app copy, screenshots captured; no live network.\nProduction simulator bundle compiled, not launched; no physical device acceptance.\n' > "$OUT/evidence/smoke-result.txt"
