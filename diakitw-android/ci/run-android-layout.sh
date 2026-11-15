#!/usr/bin/env bash
set -euo pipefail
cd diakitw-android
gradle --no-daemon :app:assembleDebug :app:assembleDebugAndroidTest
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb install -r app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk

# The emulator needs network for SDK setup, but the app/probe must start offline.
# Shell cannot send AIRPLANE_MODE on API 35; the disposable google_apis AVD allows adbd root.
root_ready=0
for attempt in 1 2 3; do
  adb root >/dev/null 2>&1 || : # adbd restart can close the client before a reply
  adb wait-for-device
  if [ "$(adb shell id -u | tr -d "\r")" = 0 ]; then root_ready=1; break; fi
  sleep 2
done
[ "$root_ready" = 1 ] || { printf "FAIL: emulator root unavailable; app not launched\n" >&2; exit 1; }
adb shell cmd connectivity airplane-mode enable
adb shell svc wifi disable
adb shell svc data disable
# Google APIs AVD can keep an Ethernet default network despite airplane mode.
# Shut down only interfaces carrying a default route; never start the app if isolation fails.
routes=$( { adb shell ip -o route show default; adb shell ip -6 -o route show default; } )
interfaces=$(printf "%s\n" "$routes" | python3 -c "import re,sys;print(chr(32).join(sorted(set(re.findall(r\"dev ([A-Za-z0-9_.-]+)\",sys.stdin.read())))))")
for iface in $interfaces; do
  [[ "$iface" =~ ^[A-Za-z0-9_.-]+$ ]] || { printf "Invalid interface name\n" >&2; exit 1; }
  adb shell ip link set "$iface" down
done
adb shell settings put global airplane_mode_on 1
[ "$(adb shell settings get global airplane_mode_on | tr -d '\r')" = 1 ]
# Android ConnectivityService reports "none" only when no default network exists.
offline=0
for attempt in $(seq 1 15); do
  if adb shell dumpsys connectivity | tr -d '\r' | grep -Eq '^[[:space:]]*Active default network: none[[:space:]]*$'; then offline=1; break; fi
  sleep 2
done
if [ "$offline" != 1 ]; then
  printf "route-interfaces-before: %s\n" "$interfaces" >&2
  adb shell dumpsys connectivity | python3 -c "import re,sys;s=sys.stdin.read();m=re.search(r\"Active default network:[^\n]*\",s);print(\"default-network-state:\",re.sub(r\"(?:\d{1,3}\.){3}\d{1,3}\",\"[ip]\",m.group(0)[:100]) if m else \"missing\")" >&2
  printf "FAIL: emulator still has a default network; app was not launched\n" >&2
  exit 1
fi
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
    python3 - "$report" <<PYPROBE
import pathlib,re,sys
content=pathlib.Path(sys.argv[1]).read_text(errors="replace")
lines=content.splitlines()
print("probe diagnostics: report_bytes=", len(content), "line_count=", len(lines))
for line in lines[:12]:
    safe=re.sub(r"\b(?:\d{1,3}\.){3}\d{1,3}\b", "[redacted-ip]", line)
    safe=re.sub(r"(?:[a-f0-9]{1,4}:){2,}[a-f0-9:]*", "[redacted-ip6]", safe, flags=re.I)
    safe=re.sub(r"[A-Za-z0-9+/]{50,}={0,2}", "[redacted-long-value]", safe)
    print("probe diagnostics: report line:", safe[:240])
PYPROBE
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
