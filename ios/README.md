# diakitw iOS 0.5.3 (53)

Unsigned build-only candidate, iOS deployment target 16.0. No certificates, Apple account, device installation or GitHub Release publication.

Preserves the 0.5.2 monitoring, foreground cancellation, bounded speed-test consent and 2ip-through-EMCx parser/transport. Presentation uses expressive-v4: 7/9 radial arc thickness, base ±10, straight tail and dark inset hub, unchanged card/gauge dimensions and centers.

## Reproduction
GitHub standard `macos-15-intel` runner with its installed Xcode/runtime, `bash ios/Scripts/ci-build.sh`. No package dependencies or third-party actions; checkout/upload are official SHA-pinned actions. Sequential operations, two compiler workers, no paid larger runner. Actual toolchain is recorded in evidence.

The source archive includes this project plus MIT LICENSE and NOTICE. Device and simulator ZIPs contain production apps only. Device app is unsigned and **not installable as delivered**. Simulator UI smoke uses a separate, unshipped source copy with deterministic local transport and marked TEST FIXTURE data; no live geolocation or speed requests. Production Monitor and transport have no fixture hooks. Host logic tests, native simulator XCTest, two cold launch screenshots (present/unknown) are distinct evidence layers. Screenshots are not physical-device evidence; minimum-OS and accessibility/device matrix remain untested.
