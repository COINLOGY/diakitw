#!/usr/bin/env bash
set -euo pipefail
cd diakitw-android
gradle --no-daemon :app:assembleDebug :app:assembleDebugAndroidTest
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb install -r app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
root_ready=0
for attempt in 1 2 3; do
  adb root >/dev/null 2>&1 || :
  adb wait-for-device
  if [ "$(adb shell id -u | tr -d '\r')" = 0 ]; then root_ready=1; break; fi
  sleep 2
done
[ "$root_ready" = 1 ] || { echo 'FAIL emulator root; no app launch' >&2; exit 1; }
adb shell cmd connectivity airplane-mode enable
adb shell svc wifi disable
adb shell svc data disable
routes=$( { adb shell ip -o route show default; adb shell ip -6 -o route show default; } )
interfaces=$(printf '%s\n' "$routes" | python3 -c 'import re,sys;print(" ".join(sorted(set(re.findall(r"dev ([A-Za-z0-9_.-]+)",sys.stdin.read())))))')
for iface in $interfaces; do
  [[ "$iface" =~ ^[A-Za-z0-9_.-]+$ ]] || exit 1
  adb shell ip link set "$iface" down
done
check_offline() {
  local state
  state=$(adb shell dumpsys connectivity | tr -d '\r')
  printf '%s\n' "$state" | grep -E '^[[:space:]]*Active default network: none[[:space:]]*$' >/dev/null
  [ -z "$(adb shell ip -o route show default)" ]
  [ -z "$(adb shell ip -6 -o route show default)" ]
}
offline=0
for attempt in $(seq 1 15); do
  if check_offline; then offline=1; break; fi
  sleep 2
done
[ "$offline" = 1 ] || { echo 'FAIL default network exists; no app launch' >&2; exit 1; }
adb shell pm clear app.diakitw
report="${RUNNER_TEMP:-/tmp}/android-entry-probe.txt"
# Debug-only diakitw.test.offline suppresses all app background requests throughout this run.
adb shell am instrument -w -e mode entry app.diakitw.test/app.diakitw.LayoutProbe > "$report"
if ! grep -Fq 'PASS exact visible/accessibility IP / карта; accessibility click directly to IP' "$report" || grep -Fq 'FAIL ' "$report" || grep -Fq 'INSTRUMENTATION_FAILED' "$report"; then
  echo 'FAIL native entry probe; raw report withheld (may contain IP)' >&2
  exit 1
fi
check_offline || { echo 'FAIL default network returned during probe' >&2; exit 1; }
printf 'PASS native entry flag FI, IP/map accessibility, offline fixtures; source %s\n' "$GITHUB_SHA" > release-candidate/native-entry-status.txt
