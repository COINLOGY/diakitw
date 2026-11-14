#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p evidence .build
export TMPDIR="${TMPDIR:-$PWD/.build/tmp}"
mkdir -p "$TMPDIR"
swiftc -j 2 -swift-version 5 Sources/Dial.swift Tests/main.swift -o .build/core-tests
.build/core-tests
swiftc -j 2 -swift-version 5 Sources/NetworkPolicy.swift Tests/NetworkTests.swift -o .build/network-tests
.build/network-tests
swiftc -j 2 -swift-version 5 Sources/NetworkPolicy.swift Tests/ProxyTests.swift -o .build/proxy-tests
.build/proxy-tests
swiftc -j 2 -swift-version 5 Sources/BoundedTransfer.swift Tests/TransportTests.swift -o .build/transport-tests
.build/transport-tests
swiftc -frontend -parse Sources/*.swift
python3 Scripts/test_monitor_host.py
plutil -lint Info.plist PrivacyInfo.xcprivacy diakitw.xcodeproj/project.pbxproj
python3 Scripts/validate_project.py
