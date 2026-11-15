# diakitw iOS 1.0.2 (102)

User-facing version **1.0.2**. Apple platform metadata and updater identity are **1.0.2**, build **101**. The updater only offers a newer, matching iOS asset when the public feed actually contains one; it does not install unsigned archives.

Unsigned build-only candidate, iOS deployment target 16.0. No certificates, Apple account, device installation or GitHub Release publication in this workflow. Device ZIP **cannot be installed directly**. A developer must sign/provision an appropriate device build; the simulator archive is not an iPhone installer.

## Internet test and report

- One visible **Старт** immediately starts one bounded run. The traffic notice appears before the button; tapping it is consent. No second confirmation modal and no speed test on view open.
- **PING · HTTP**, in milliseconds, is one monotonic-clock measurement around a complete successful HTTPS GET `https://speed.cloudflare.com/__down?bytes=0`. It includes DNS/TCP/TLS as applicable, server processing and complete response delivery, not ICMP RTT, jitter or packet loss. Response cap: 4 KiB. Failed, invalid or unfinished measurements display **Н/Д**, never a fabricated zero.
- Next: download 8 MiB, synthetic upload 2 MiB (upload response cap 4 KiB). Each of three requests has a 22-second wall-clock deadline: up to 66 seconds. Protocol overhead/network buffers are additional; this is not an exact carrier-traffic quota. No user files are sent. Failed HTTP latency does not prevent the independent throughput test.
- Cancel/background stops work. Completed partial readings remain valid; cancelled pending readings cannot overwrite them. New Start clears previous readings. Duplicate starts while running are ignored.

The updater automatically checks at each active cold launch and later by its foreground schedule; a matching feed offer opens the release page only on user action. No downloaded bytes are verified in-app and there is no automatic download or installation. The updater remains browser-only. An Android-only release manifest does not produce an iOS installation offer; unsigned iOS archives may be listed separately on the release page by the release owner. No live feed is changed here. Offline version/selection fixtures are not evidence that an actual older installed iOS client received an update notification.

## Reproduction and evidence

GitHub standard `macos-15-intel`, installed Xcode 16.4/runtime, `bash ios/Scripts/ci-build.sh`. Sequential operations, two compiler workers, no expanded device matrix or paid larger runner. Official checkout/upload actions pinned by SHA. CI uploads toolchain logs, unsigned device/simulator archives, source with MIT LICENSE and NOTICE, SHA256SUMS, simulator XCTest result bundle and screenshots.

All original gates remain: host tests, bounded transport tests, update-parser/transport/lifecycle tests, project/plist/presentation validation, device and simulator compilation, simulator XCTest, two cold launches of an unshipped fixture app (present/unknown). New XCTest covers HTTP latency formatting, normal/failure/cancellation/background cases, no auto-start, single invocation and resetting previous latency. Static regression gate checks direct Start, prior notice and absence of modal confirmation.

Screenshots show the real production report/notice/button scrolled into view in a separate, labelled TEST FIXTURE copy: 25.0 ms present and Н/Д unknown. Fixture values are illustrative, not a live internet measurement. Production archives contain no fixture environment hooks. UI screenshots are not an automated tap test or physical-device acceptance; model invocation is exercised independently by XCTest. Minimum-OS and accessibility/device matrix remain untested.
