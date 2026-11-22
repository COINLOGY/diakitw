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
# The app is offline by debug-only intent and the emulator has no default routes.
adb shell settings put system accelerometer_rotation 0
for variant in portrait landscape large-font; do
  case "$variant" in
    portrait) adb shell wm size 1080x1920; adb shell settings put system font_scale 1.0; expected=1; font=1.0 ;;
    landscape) adb shell wm size 1920x1080; adb shell settings put system user_rotation 1; adb shell settings put system font_scale 1.0; expected=2; font=1.0 ;;
    large-font) adb shell wm size 1080x1920; adb shell settings put system user_rotation 0; adb shell settings put system font_scale 1.6; expected=1; font=1.6 ;;
  esac
  adb shell am force-stop app.diakitw || :
  check_offline || { echo 'FAIL network returned before native probe' >&2; exit 1; }
  report="${RUNNER_TEMP:-/tmp}/android-107-${variant}.txt"
  if ! adb shell am instrument -w -e mode release107 -e orientation "$expected" -e minFontScale "$font" app.diakitw.test/app.diakitw.LayoutProbe > "$report"; then
    python3 ci/safe-probe-summary.py "$report" >&2; exit 1
  fi
  if ! grep -Fq 'PASS release107 offline resources, RX/TX, disk, map visible, folder grant gate' "$report" || grep -Fq 'FAIL ' "$report" || grep -Fq 'INSTRUMENTATION_FAILED' "$report"; then
    python3 ci/safe-probe-summary.py "$report" >&2; exit 1
  fi
  check_offline || { echo 'FAIL network returned during native probe' >&2; exit 1; }
done
# Reset to standard presentation after the separate large-font acceptance.
# Entry tests assert accessibility and no-scroll layout at the normal viewport.
adb shell am force-stop app.diakitw || :
adb shell wm size 1080x1920
adb shell settings put system user_rotation 0
adb shell settings put system font_scale 1.0
check_offline || { echo 'FAIL network returned during display reset' >&2; exit 1; }
# The existing entry route checks the verified ISO country flag on visible compact cards.
check_offline || { echo 'FAIL network returned before entry probe' >&2; exit 1; }
report="${RUNNER_TEMP:-/tmp}/android-107-entry.txt"
if ! adb shell am instrument -w -e mode entry app.diakitw.test/app.diakitw.LayoutProbe > "$report"; then
  python3 ci/safe-probe-summary.py "$report" >&2; exit 1
fi
if ! grep -Fq 'PASS exact visible/accessibility IP / карта; accessibility click directly to IP' "$report" || grep -Fq 'FAIL ' "$report" || grep -Fq 'INSTRUMENTATION_FAILED' "$report"; then
  python3 ci/safe-probe-summary.py "$report" >&2; exit 1
fi
check_offline || { echo 'FAIL network returned during entry probe' >&2; exit 1; }
# The native UI assertions above exercise the debuggable build. Separately
# install and launch the *signed release bytes* on the same offline emulator.
# Debug and release have different signatures, so replace rather than update.
adb shell am force-stop app.diakitw || :
adb uninstall app.diakitw >/dev/null
signed=release-candidate/diakitw-android-1.0.7.apk
[ -s "$signed" ] || { echo 'FAIL signed candidate missing' >&2; exit 1; }
check_offline || { echo 'FAIL network returned before signed launch' >&2; exit 1; }
adb install "$signed" >/dev/null
adb shell am start -W -n app.diakitw/.MainActivity > "${RUNNER_TEMP:?}/signed-107-launch.txt"
sleep 3
[ -n "$(adb shell pidof app.diakitw | tr -d '\r')" ] || { echo 'FAIL signed release process exited' >&2; exit 1; }
package=$(adb shell dumpsys package app.diakitw | tr -d '\r')
printf '%s\n' "$package" | grep -F 'versionCode=107' >/dev/null
printf '%s\n' "$package" | grep -F 'versionName=1.0.7' >/dev/null
check_offline || { echo 'FAIL network returned during signed launch' >&2; exit 1; }
# Keep only bounded, non-sensitive evidence; never upload logs with IP fields.
printf 'PASS signed release APK installed and launched offline; build 107; source %s\n' "$GITHUB_SHA" > release-candidate/signed-107-smoke.txt
printf 'PASS native DEBUG probes: release107 portrait, landscape, large-font; measured RX/TX, scoped disk, map, offline fixtures. PASS signed RELEASE smoke: installed and launched offline; source %s\n' "$GITHUB_SHA" > release-candidate/native-107-status.txt
