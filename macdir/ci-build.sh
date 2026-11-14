#!/bin/bash
# CI entry point only: no release, deployment, secrets, signing keys or live app.
set -euo pipefail
cd "$(dirname "$0")"
[[ "${GITHUB_ACTIONS:-}" == true && "$(uname -m)" == arm64 ]]
export DEVELOPER_DIR="$(xcode-select -p)"
export MACOSX_DEPLOYMENT_TARGET=14.0
export MACDIR_TEST_SCRATCH="$GITHUB_WORKSPACE/.ci-scratch"
mkdir -p "$MACDIR_TEST_SCRATCH" evidence/diakitw-0.5.3
export TMPDIR="$(cd "$MACDIR_TEST_SCRATCH" && pwd -P)"
{
  printf 'Commit: %s\nRunner: %s / %s\n' "$GITHUB_SHA" "$RUNNER_OS" "$RUNNER_ARCH"
  sw_vers
  xcodebuild -version
  swift --version
  xcrun --sdk macosx --show-sdk-path
  printf '%s\n' 'Hardware stress/GPU worker/live network/production SSH/Keychain/installed GUI: NOT RUN (not authorized).'
} | tee evidence/diakitw-0.5.3/toolchain.log
# Preserve every existing build.sh gate, including real APFS and offscreen renders.
bash build.sh 2>&1 | tee evidence/diakitw-0.5.3/build-arm64.log
swift build --jobs 2 --build-system native -c release \
  --scratch-path .build-diakitw-intel --triple x86_64-apple-macosx14.0 \
  --sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -Xswiftc -file-prefix-map -Xswiftc "$PWD=/diakitw-src" \
  -Xswiftc -debug-prefix-map -Xswiftc "$PWD=/diakitw-src" \
  2>&1 | tee evidence/diakitw-0.5.3/build-intel.log
python3 package-diagnostics-dmg.py 2>&1 | tee evidence/diakitw-0.5.3/package.log
python3 Tests/verify_ci_artifacts.py 2>&1 | tee evidence/diakitw-0.5.3/final-verification.log
