# Apple update checker · 0.5.4 / build 54

Stage 1: notify/check/open browser only. No package download by the app, no execution, self-install, forced restart, Sparkle or certificate setup. The downloaded file's SHA-256/signature is **not** verified by this checker. macOS distributions remain ad-hoc signed, not notarized. Unsigned iOS is not installable from the release page.

## Shared contract (also used by other platforms)

Fixed endpoint: `https://coinlogy.github.io/diakitw/updates/v1.json`.

`{"schema":1,"releases":[{"version":"0.5.4","build":54,"channel":"preview","notes":"Plain text","assets":{"macos-arm64":{"url":"https://github.com/COINLOGY/diakitw/releases/download/v0.5.4/diakitw-0.5.4-macos-arm64.dmg","size":123,"sha256":"<64 hex digits>"}}}]}`

The example is documentation, **not a live feed**. Publish the feed only after real assets, sizes and hashes exist. Missing/404 feed is an error, never an up-to-date result.

- Numeric three-component version, nonnegative integer build, schema integer 1. No downgrade; newer build accepted at equal version. Same channel only. Preview default; an explicit Stable choice persists and never admits Preview.
- Keys: `macos-arm64`, `macos-x86_64`, `windows-x64`, `linux-x64`, `android`, `ios-unsigned`. macOS hardware architecture is discovered at runtime, including Apple Silicon under Rosetta. Missing matching architecture means no offer, never fallback.
- HTTPS GitHub owner/repository/download/version prefix is exact. Filename is one bounded ASCII basename; no escapes, query, credentials, port, fragment or path traversal. Selected Apple filenames must exactly match `diakitw-VERSION-macos-arm64.dmg`, `diakitw-VERSION-macos-x86_64.dmg`, or `diakitw-VERSION-ios-UNSIGNED-device.app.zip`. iOS opens only the constructed `/releases/tag/vVERSION` page.
- Assets require positive integer size and 64-hex SHA-256 metadata. Notes are bounded plaintext (2000 UTF-8 bytes), never rendered HTML/Markdown.
- Ephemeral request; 10-second resource deadline and 32 KiB streamed response cap; no redirects, cookies, credentials, disk cache, telemetry body or private query parameters. GitHub necessarily sees the ordinary connection IP.
- Foreground/startup auto check with persisted 24-hour success interval, 1-hour failure cooldown. Manual retry minimum 60 seconds. No concurrent logical checks; cancellation/generation guards reject stale completions on hide/quit/channel change. Later dismisses and postpones auto checking for 24 hours.

## Source and acceptance

`macdir/Sources/MacdirCore/UpdateChecker.swift` and `ios/Sources/UpdateChecker.swift` must remain byte-identical. `check_updates_wiring.py` asserts parity. `update_checks.swift` exercises the actual shared source with old/current/downgrade/channel/architecture/URL/schema fixtures, injected transport and fake time/persistence/cancellation. Both Apple CI workflows run these tests, existing regression gates, and unsigned/ad-hoc builds. No fixture launches a root scan or contacts a live update feed. This file describes intended contracts; run-specific results belong in CI evidence.

macOS UI: app menu and telemetry menu entry, nonmodal available-version title, separate native update window with Check/Download/Later/channel controls; existing dashboard heights, needles and space-padded menu metrics unchanged. iOS UI: an inline update section after existing controls, plus unsigned-install warning.
