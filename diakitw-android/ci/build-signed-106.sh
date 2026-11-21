#!/usr/bin/env bash
set -euo pipefail
umask 077
cd diakitw-android
: "${DIAKITW_ANDROID_P12_BASE64:?Missing signing identity secret}"
: "${DIAKITW_ANDROID_P12_PASSWORD:?Missing signing password secret}"
: "${ANDROID_HOME:?Missing Android SDK}"
archive_dir=$(mktemp -d)
trap 'rm -rf "$archive_dir"' EXIT
printf '%s' "$DIAKITW_ANDROID_P12_BASE64" | base64 --decode > "$archive_dir/release.p12"
gradle --no-daemon :app:assembleRelease
unsigned=app/build/outputs/apk/release/app-release-unsigned.apk
[ -s "$unsigned" ] || { echo 'No unsigned Gradle output' >&2; exit 1; }
mkdir -p release-candidate
aligned="$archive_dir/aligned.apk"
signed=release-candidate/diakitw-android-1.0.6.apk
rm -f "$signed"
"$ANDROID_HOME/build-tools/35.0.0/zipalign" -f -p 4 "$unsigned" "$aligned"
"$ANDROID_HOME/build-tools/35.0.0/apksigner" sign --ks "$archive_dir/release.p12" --ks-type PKCS12 --ks-key-alias diakitw-release-101 --ks-pass env:DIAKITW_ANDROID_P12_PASSWORD --out "$signed" "$aligned"
"$ANDROID_HOME/build-tools/35.0.0/zipalign" -c -v 4 "$signed" >/dev/null
"$ANDROID_HOME/build-tools/35.0.0/apksigner" verify --verbose --print-certs "$signed" | python3 -c 'import re,sys; text=sys.stdin.read(); expected="d9298271dcb4e32856abdc2111b35ae43b7770b1c9fbfefa66100e899a58abc8"; matches=re.findall(r"Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]{64})",text); assert len(matches)==1 and matches[0].lower()==expected, "Unexpected APK signing certificate"; assert "Verified using v2 scheme (APK Signature Scheme v2): true" in text, "Missing v2 signature"; print("PASS signed APK cert SHA256:",expected)'
sha256sum "$signed" > release-candidate/SHA256SUMS.txt
printf 'source_sha=%s\n' "$GITHUB_SHA" > release-candidate/source-commit.txt
