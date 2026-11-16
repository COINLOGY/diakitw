#!/bin/bash
# Standard ephemeral macOS runner only. Secrets stay in env/0600 files, never logs.
set -euo pipefail
for key in MACDIR_DEVELOPER_ID MACDIR_SIGNING_P12_BASE64 MACDIR_SIGNING_P12_PASSWORD MACDIR_NOTARY_KEY_BASE64 MACDIR_NOTARY_KEY_ID MACDIR_NOTARY_ISSUER; do
  [[ -n "${!key:-}" ]] || { echo "Missing required signing credential: $key" >&2; exit 1; }
done
[[ "$MACDIR_DEVELOPER_ID" == 'Developer ID Application:'* ]] || { echo 'Not a Developer ID Application identity' >&2; exit 1; }
[[ "${GITHUB_ACTIONS:-}" == true && -n "${RUNNER_TEMP:-}" ]] || { echo 'Only GitHub runner may provision keychain' >&2; exit 1; }
umask 077
keychain="$RUNNER_TEMP/diakitw-103-signing.keychain-db"
p12="$RUNNER_TEMP/diakitw-103-signing.p12"
key="$RUNNER_TEMP/diakitw-103-notary.p8"
[[ ! -e "$keychain" && ! -e "$p12" && ! -e "$key" ]] || { echo 'Refusing existing credential files' >&2; exit 1; }
# A failed step still triggers the workflow cleanup step.
password="$(openssl rand -hex 32)"
security create-keychain -p "$password" "$keychain"
security unlock-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
printf '%s' "$MACDIR_SIGNING_P12_BASE64" | base64 -D > "$p12"
security import "$p12" -k "$keychain" -P "$MACDIR_SIGNING_P12_PASSWORD" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple: -s -k "$password" "$keychain" >/dev/null
rm -f "$p12"
printf '%s' "$MACDIR_NOTARY_KEY_BASE64" | base64 -D > "$key"
xcrun notarytool store-credentials diakitw-103-ci --key "$key" --key-id "$MACDIR_NOTARY_KEY_ID" --issuer "$MACDIR_NOTARY_ISSUER" --keychain "$keychain" >/dev/null
rm -f "$key"
printf 'MACDIR_SIGNING_KEYCHAIN=%s\nMACDIR_NOTARY_PROFILE=diakitw-103-ci\n' "$keychain" >> "$GITHUB_ENV"
MACDIR_SIGNING_KEYCHAIN="$keychain" MACDIR_NOTARY_PROFILE=diakitw-103-ci bash sign-and-notarize.sh preflight
printf '%s\n' 'Developer ID and notarization credentials validated; no secret values logged.'
