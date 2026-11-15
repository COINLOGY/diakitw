#!/usr/bin/env bash
set -euo pipefail
cd diakitw-android
gradle --no-daemon :app:assembleDebug :app:assembleDebugAndroidTest
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb install -r app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk

# The emulator needs network for SDK setup, but the app/probe must start offline.
adb shell svc wifi disable
adb shell svc data disable
adb shell settings put global airplane_mode_on 1
[ "$(adb shell settings get global airplane_mode_on | tr -d '\r')" = 1 ]
# Android ConnectivityService reports "none" only when no default network exists.
offline=0
for attempt in $(seq 1 15); do
  if adb shell dumpsys connectivity | tr -d '\r' | grep -Eq '^[[:space:]]*Active default network: none[[:space:]]*$'; then offline=1; break; fi
  sleep 2
done
if [ "$offline" != 1 ]; then printf 'FAIL: emulator still has a default network; app was not launched\n' >&2; exit 1; fi
adb shell pm clear app.diakitw
mkdir -p emulator-evidence
printf '%s\n' "$GITHUB_SHA" > emulator-evidence/source-commit.txt
for rotation in portrait landscape; do
  adb shell settings put system accelerometer_rotation 0
  if [ "$rotation" = portrait ]; then angle=0; else angle=1; fi
  adb shell settings put system user_rotation "$angle"
  sleep 3
  report="${RUNNER_TEMP:-/tmp}/android-layout-$rotation.txt"
  adb shell am instrument -w -e mode arrow -e orientation "$angle" app.diakitw.test/app.diakitw.LayoutProbe > "$report"
  if ! grep -Fq 'INSTRUMENTATION_CODE: -1' "$report" || ! grep -Fq 'PASS network arrow native bounds' "$report"; then
    printf 'FAIL: native layout probe, %s; raw report not published\n' "$rotation" >&2
    exit 1
  fi
  printf 'PASS network arrow native bounds; INSTRUMENTATION_CODE: -1; %s; source %s\n' "$rotation" "$GITHUB_SHA" > "emulator-evidence/layout-$rotation-status.txt"
  adb exec-out run-as app.diakitw cat cache/047-speed-idle.png > "emulator-evidence/speed-idle-$rotation.png"
  python3 - "emulator-evidence/speed-idle-$rotation.png" <<'PY'
import pathlib,sys
image=pathlib.Path(sys.argv[1]).read_bytes()
assert len(image)>100 and image.startswith(b'\x89PNG\r\n\x1a\n'), 'Missing or invalid speed-dials-only screenshot'
PY
  printf 'PASS: %s native layout and speed-dials-only PNG\n' "$rotation"
done
