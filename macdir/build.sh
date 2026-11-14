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
OUTPUT="${MACDIR_OUTPUT:-dist/diakitw-0.5.4-arm64}"
if [[ -e "$OUTPUT" || -L "$OUTPUT" ]]; then
  printf '%s\n' "Refusing existing output: $OUTPUT" >&2
  exit 1
fi
if [[ "$(uname -m)" != arm64 ]]; then
  printf '%s\n' "This entry point builds arm64; use the documented Intel cross-build." >&2
  exit 1
fi
python3 Tests/check_updates_wiring.py
mkdir -p evidence/diakitw-0.5.4
swiftc -j 2 -parse-as-library Sources/MacdirCore/UpdateChecker.swift Tests/update_checks.swift -o evidence/diakitw-0.5.4/update-checks
evidence/diakitw-0.5.4/update-checks
python3 Tests/check_expressive_v4.py
python3 Tests/check_menu_spaces.py
python3 Tests/check_rebrand.py
python3 Tests/check_final_brand.py
python3 Tests/check_diagnostic_p0_ui.py
python3 Tests/check_metric_pairs.py
python3 Tests/check_release_artifacts.py
swift build --jobs 2 --build-system native -c release --triple arm64-apple-macosx14.0 --sdk "$(xcrun --sdk macosx --show-sdk-path)" -Xswiftc -file-prefix-map -Xswiftc "$PWD=/diakitw-src" -Xswiftc -debug-prefix-map -Xswiftc "$PWD=/diakitw-src"
.build/release/CoreChecks
.build/release/CacheChecks
.build/release/ServerChecks
.build/release/InternetChecks
.build/release/TrafficChecks
.build/release/DiagnosticChecks
python3 Tests/check_diagnostics_ui.py
python3 Tests/check_diagnostic_presentation.py
python3 Tests/check_diagnostic_allocation.py
mkdir -p evidence/diakitw-0.5.4
swiftc -j 2 -parse-as-library Sources/macdir/DiagnosticControls.swift Tests/render_diagnostics.swift -I .build/release/Modules .build/release/MacdirCore.build/*.o -o evidence/diakitw-0.5.4/render-diagnostics
evidence/diakitw-0.5.4/render-diagnostics
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
swiftc -j 2 -parse-as-library Sources/MacdirCore/MacIdentity.swift Sources/MacdirCore/EgressLocation.swift Tests/geo_checks.swift -o evidence/diakitw-0.5.4/geo-checks
evidence/diakitw-0.5.4/geo-checks
swiftc -j 2 -parse-as-library Sources/macdir/DesktopActions.swift Tests/desktop_actions_checks.swift -o evidence/diakitw-0.5.4/desktop-actions-checks
evidence/diakitw-0.5.4/desktop-actions-checks
swiftc -j 2 -parse-as-library Sources/MacdirCore/IdentityRefreshPolicy.swift Tests/identity_refresh_checks.swift -o evidence/diakitw-0.5.4/identity-refresh-checks
evidence/diakitw-0.5.4/identity-refresh-checks
python3 Tests/check_cache_ui.py
python3 Tests/check_startup.py
python3 Tests/check_gauges.py
python3 Tests/check_instrument_style.py
swiftc -j 2 -parse-as-library Sources/MacdirCore/GaugeScale.swift Tests/gauge_geometry_checks.swift -o evidence/diakitw-0.5.4/geometry-checks
evidence/diakitw-0.5.4/geometry-checks
swiftc -j 2 -parse-as-library Sources/MacdirCore/GaugeScale.swift Tests/needle_geometry_checks.swift -o evidence/diakitw-0.5.4/needle-checks
evidence/diakitw-0.5.4/needle-checks
swiftc -j 2 -parse-as-library Sources/macdir/NeedleGauge.swift Sources/macdir/NetworkRateValue.swift Tests/render_gauge_geometry.swift -I .build/release/Modules .build/release/MacdirCore.build/*.o -o evidence/diakitw-0.5.4/gauge-checks
evidence/diakitw-0.5.4/gauge-checks evidence/diakitw-0.5.4/gauge-green
swiftc -j 2 -parse-as-library Sources/MacdirCore/GaugeScale.swift Tests/speed_scale_checks.swift -o evidence/diakitw-0.5.4/speed-checks
evidence/diakitw-0.5.4/speed-checks
python3 Tests/check_swap_ui.py
python3 Tests/check_network_colors.py
python3 Tests/check_hud.py
python3 Tests/check_status_legibility.py
python3 Tests/check_layout.py 0.5.4
mkdir -p evidence/diakitw-0.5.4/status
swiftc -j 2 Sources/macdir/StatusTypography.swift Tests/render_status.swift -o evidence/diakitw-0.5.4/status/render-status
evidence/diakitw-0.5.4/status/render-status evidence/diakitw-0.5.4/status
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
codesign --force --sign - "$APP/Contents/MacOS/DiagnosticWorker"
codesign --force --sign - "$APP/Contents/MacOS/ServerAskpass"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT/diakitw-0.5.4-macos-arm64.zip"
