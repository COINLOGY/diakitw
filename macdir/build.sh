#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
# Tests create only owned fixtures; macOS /var aliases fail no-symlink guards.
export TMPDIR="${MACDIR_TEST_SCRATCH:-$HOME/.cache/diakitw/scratch}"
mkdir -p "$TMPDIR"
export TMPDIR="$(cd "$TMPDIR" && pwd -P)"
# Pin per-process toolchain: other platform builds may change xcode-select.
export DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
export MACOSX_DEPLOYMENT_TARGET=14.0
# Refuse prior outputs before compiling or writing any release artifacts.
OUTPUT="${MACDIR_OUTPUT:-dist/diakitw-1.0.6-arm64}"
if [[ -e "$OUTPUT" || -L "$OUTPUT" ]]; then
  printf '%s\n' "Refusing existing output: $OUTPUT" >&2
  exit 1
fi
if [[ "$(uname -m)" != arm64 ]]; then
  printf '%s\n' "This entry point builds arm64; use the documented Intel cross-build." >&2
  exit 1
fi
if [[ "${MACDIR_SIGNING_MODE:-signed}" == adhoc ]]; then
  [[ "${GITHUB_ACTIONS:-}" == true ]] || { echo 'Ad-hoc build restricted to CI' >&2; exit 2; }
  SIGN_COMMAND=adhoc-sign
  bash sign-and-notarize.sh adhoc-preflight
else
  [[ "${MACDIR_SIGNING_MODE:-signed}" == signed ]] || exit 2
  SIGN_COMMAND=sign
  bash sign-and-notarize.sh preflight
fi
python3 Tests/check_updates_wiring.py
python3 Tests/test_release_106_mac.py
python3 Tests/check_release106_mac_layout.py
python3 Tests/test_compact_106.py
python3 Tests/test_macos_adhoc_route_106.py
python3 Tests/check_update_prompt.py
mkdir -p evidence/diakitw-1.0.6
swiftc -j 2 -parse-as-library Sources/macdir/UpdateOfferPromptPolicy.swift Tests/update_prompt_checks.swift -o evidence/diakitw-1.0.6/update-prompt-checks
evidence/diakitw-1.0.6/update-prompt-checks
swiftc -j 2 -parse-as-library Sources/MacdirCore/UpdateChecker.swift Tests/update_checks.swift -o evidence/diakitw-1.0.6/update-checks
evidence/diakitw-1.0.6/update-checks
python3 Tests/check_expressive_v4.py
python3 Tests/check_menu_spaces.py
python3 Tests/check_rebrand.py
python3 Tests/check_final_brand.py
python3 Tests/check_diagnostic_p0_ui.py
python3 Tests/check_metric_pairs.py
python3 Tests/check_release_artifacts.py
swift build --jobs 2 --build-system native -c release --triple arm64-apple-macosx14.0 --sdk "$(xcrun --sdk macosx --show-sdk-path)" -Xswiftc -file-prefix-map -Xswiftc "$PWD=/diakitw-src" -Xswiftc -debug-prefix-map -Xswiftc "$PWD=/diakitw-src"
 swiftc -j 2 -parse-as-library Tests/battery_cycles_checks.swift -I .build/release/Modules .build/release/MacdirCore.build/*.o -o evidence/diakitw-1.0.6/battery-cycles-checks
 evidence/diakitw-1.0.6/battery-cycles-checks
.build/release/CoreChecks
.build/release/CacheChecks
.build/release/ServerChecks
.build/release/InternetChecks
.build/release/TrafficChecks
.build/release/DiagnosticChecks
python3 Tests/check_diagnostics_ui.py
python3 Tests/check_diagnostic_presentation.py
python3 Tests/check_diagnostic_allocation.py
mkdir -p evidence/diakitw-1.0.6
swiftc -j 2 -parse-as-library Sources/macdir/DiagnosticControls.swift Tests/render_diagnostics.swift -I .build/release/Modules .build/release/MacdirCore.build/*.o -o evidence/diakitw-1.0.6/render-diagnostics
evidence/diakitw-1.0.6/render-diagnostics
python3 Tests/run_server_auth_checks.py "${TMPDIR:?Set an owned scratch directory}"
python3 Tests/check_server_metric_integration.py
python3 Tests/run_server_management_checks.py "${TMPDIR:?Set an owned scratch directory}"
python3 Tests/check_traffic_ui.py
python3 Tests/check_internet_ui.py
python3 Tests/test_server_probe.py
python3 Tests/check_servers_ui.py
python3 Tests/check_mac_identity.py
python3 Tests/check_geo_wiring.py
python3 Tests/check_geo_transport.py
swiftc -j 2 -parse-as-library Sources/MacdirCore/MacIdentity.swift Sources/MacdirCore/EgressLocation.swift Tests/geo_checks.swift -o evidence/diakitw-1.0.6/geo-checks
evidence/diakitw-1.0.6/geo-checks
python3 Tests/test_country_flag_status.py
swiftc -j 2 -parse-as-library Sources/macdir/StatusTypography.swift Tests/status_country_flag_checks.swift -o evidence/diakitw-1.0.6/status-country-flag-checks
evidence/diakitw-1.0.6/status-country-flag-checks
swiftc -j 2 -parse-as-library Sources/macdir/DesktopActions.swift Tests/desktop_actions_checks.swift -o evidence/diakitw-1.0.6/desktop-actions-checks
evidence/diakitw-1.0.6/desktop-actions-checks
swiftc -j 2 -parse-as-library Sources/MacdirCore/IdentityRefreshPolicy.swift Tests/identity_refresh_checks.swift -o evidence/diakitw-1.0.6/identity-refresh-checks
evidence/diakitw-1.0.6/identity-refresh-checks
python3 Tests/check_cache_ui.py
python3 Tests/check_startup.py
python3 Tests/check_gauges.py
python3 Tests/check_instrument_style.py
swiftc -j 2 -parse-as-library Sources/MacdirCore/GaugeScale.swift Tests/gauge_geometry_checks.swift -o evidence/diakitw-1.0.6/geometry-checks
evidence/diakitw-1.0.6/geometry-checks
swiftc -j 2 -parse-as-library Sources/MacdirCore/GaugeScale.swift Tests/needle_geometry_checks.swift -o evidence/diakitw-1.0.6/needle-checks
evidence/diakitw-1.0.6/needle-checks
swiftc -j 2 -parse-as-library Sources/macdir/NeedleGauge.swift Sources/macdir/NetworkRateValue.swift Tests/render_gauge_geometry.swift -I .build/release/Modules .build/release/MacdirCore.build/*.o -o evidence/diakitw-1.0.6/gauge-checks
evidence/diakitw-1.0.6/gauge-checks evidence/diakitw-1.0.6/gauge-green
swiftc -j 2 -parse-as-library Sources/MacdirCore/GaugeScale.swift Tests/speed_scale_checks.swift -o evidence/diakitw-1.0.6/speed-checks
evidence/diakitw-1.0.6/speed-checks
python3 Tests/check_swap_ui.py
python3 Tests/check_network_colors.py
python3 Tests/check_hud.py
python3 Tests/check_status_legibility.py
python3 Tests/check_layout.py 1.0.6
mkdir -p evidence/diakitw-1.0.6/status
swiftc -j 2 Sources/macdir/StatusTypography.swift Tests/render_status.swift -o evidence/diakitw-1.0.6/status/render-status
evidence/diakitw-1.0.6/status/render-status evidence/diakitw-1.0.6/status
# Versioned output: never replace the user's installed app or previous distributions.
APP="$OUTPUT/diakitw.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/macdir "$APP/Contents/MacOS/macdir"
cp .build/release/DiagnosticWorker "$APP/Contents/MacOS/DiagnosticWorker"
cp .build/release/ServerAskpass "$APP/Contents/MacOS/ServerAskpass"
chmod 755 "$APP/Contents/MacOS/ServerAskpass"
cp Info.plist "$APP/Contents/Info.plist"
cp assets/macdir.icns "$APP/Contents/Resources/macdir.icns"
cp assets/server_probe.py "$APP/Contents/Resources/server_probe.py"
# Strip only release copies; remove Mach-O OSO debug-map build paths.
strip -S "$APP/Contents/MacOS/macdir" "$APP/Contents/MacOS/DiagnosticWorker" "$APP/Contents/MacOS/ServerAskpass"
python3 Tests/check_binary_privacy.py "$APP"
bash sign-and-notarize.sh "$SIGN_COMMAND" "$APP/Contents/MacOS/DiagnosticWorker"
bash sign-and-notarize.sh "$SIGN_COMMAND" "$APP/Contents/MacOS/ServerAskpass"
bash sign-and-notarize.sh "$SIGN_COMMAND" "$APP"
codesign --verify --deep --strict "$APP"
