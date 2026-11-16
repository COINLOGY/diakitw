#!/bin/bash
# Signed production remains Developer ID + notarization; ad-hoc is CI-only.
set -euo pipefail
mode="${1:-}"; target="${2:-}"
if [[ "$mode" == adhoc-preflight ]]; then
  # Explicit CI-only candidate; no Developer ID, notarization or Gatekeeper promise.
  [[ "${GITHUB_ACTIONS:-}" == true && "${MACDIR_SIGNING_MODE:-}" == adhoc ]] || exit 2
  exit 0
fi
if [[ "$mode" == adhoc-sign ]]; then
  [[ "${GITHUB_ACTIONS:-}" == true && "${MACDIR_SIGNING_MODE:-}" == adhoc && -e "$target" ]] || exit 2
  codesign --force --sign - "$target"
  codesign --verify --strict --verbose=2 "$target"
  exit 0
fi
[[ "$mode" == preflight || "$mode" == sign || "$mode" == notarize ]] || { echo 'Usage: sign-and-notarize.sh preflight|sign|notarize [target]' >&2; exit 2; }
[[ -n "${MACDIR_DEVELOPER_ID:-}" && "$MACDIR_DEVELOPER_ID" == 'Developer ID Application:'* ]] || { echo 'Missing Developer ID Application identity' >&2; exit 1; }
[[ -n "${MACDIR_SIGNING_KEYCHAIN:-}" && -f "$MACDIR_SIGNING_KEYCHAIN" ]] || { echo 'Missing signing keychain' >&2; exit 1; }
[[ -n "${MACDIR_NOTARY_PROFILE:-}" ]] || { echo 'Missing notarytool keychain profile' >&2; exit 1; }
identities="$(security find-identity -v -p codesigning "$MACDIR_SIGNING_KEYCHAIN")"
[[ "$identities" == *'"'"$MACDIR_DEVELOPER_ID"'"'* ]] || { echo 'Missing valid matching Developer ID identity in keychain' >&2; exit 1; }
if [[ "$mode" == preflight ]]; then
  xcrun notarytool history --keychain-profile "$MACDIR_NOTARY_PROFILE" --keychain "$MACDIR_SIGNING_KEYCHAIN" >/dev/null || { echo 'Missing/invalid notarization credentials or Apple service unreachable' >&2; exit 1; }
  exit 0
fi
[[ -e "$target" ]] || { echo 'Missing target' >&2; exit 1; }
if [[ "$mode" == sign ]]; then
  codesign --force --options runtime --timestamp --sign "$MACDIR_DEVELOPER_ID" --keychain "$MACDIR_SIGNING_KEYCHAIN" "$target"
  codesign --verify --strict --verbose=2 "$target"
else
  [[ "$target" == *.dmg ]] || { echo 'Notarization target must be DMG' >&2; exit 1; }
  # --wait must finish Accepted; a submission ID alone is not approval.
  xcrun notarytool submit "$target" --wait --keychain-profile "$MACDIR_NOTARY_PROFILE" --keychain "$MACDIR_SIGNING_KEYCHAIN" --output-format json | python3 -c 'import json,sys; status=json.load(sys.stdin).get("status"); assert status == "Accepted", "Notarization not accepted: "+str(status); print("Notarization accepted")'
  xcrun stapler staple "$target"
  xcrun stapler validate "$target"
fi
