# Changelog

## 1.0.6 (106) — preview

Geo API moved from the retired `aia.emcx.pro` host to `https://emcx.pro/diakitw-api/geo`
in every client. Android: informational dialogs are dismissed in `onPause`, the HTTP
User-Agent carries the real app version, and the 24h quota pause is cleared on network
change. Windows PE fixed version is `1.0.6.106`. macOS: endpoint-bound response decoder,
8 GiB update-asset bound, 22s speed-test resource timeout. iOS: battery monitoring is
disabled in background. Android CI verifies the pinned `json-20240303.jar` SHA-256.
Update feeds v1 (desktop/macOS) and v2 (Android) offer 1.0.6 on the preview channel.
Details and limitations: [release/1.0.6.md](release/1.0.6.md).

## 0.5.4 (54) — preview

Foreground/manual update discovery; preview default and explicit stable channel.
Browser-only downloads; no auto-install or downloaded-file verification.
Five installer platforms plus unsigned iOS development outputs/source.
Integrated source and limitations: [release/0.5.4.md](release/0.5.4.md).
Earlier clients need one manual bootstrap installation. Previous versions remain.

## 0.5.3 — previous candidate

Previous platform work and distributions are retained in Git history and releases;
see individual historical release notes, not 0.5.4 acceptance claims.

## 0.5.2 — preview

Public source release for macOS, Android, Windows/Linux and the isolated 2ip
proxy, with MIT for own code. Public source fixtures use documentation addresses;
workstation-specific build scratch paths have been made generic. Runtime code
is carried from the 0.5.2 candidate sources, not rebuilt during publication.
The supplied candidates include proxy geolocation/fallback integration and UI work.

Limitations: macOS ad-hoc/no notarization; Intel runtime unverified. Mac mutation
raster check timed out; final mounted-app self-check not confirmed. Windows/Linux
target runtime unverified; Windows no Authenticode. Android debug-signed using the
existing certificate; 0.5.2 GUI acceptance unverified. Earlier-version tests are
not proof of 0.5.2 device/runtime behavior. No iOS source or IPA in this release.

## 0.4.5

Previous distribution release remains available in GitHub releases/history.
