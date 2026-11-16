"""Lightweight source gate; runtime behavior is tested by update_checks.swift in CI."""
from pathlib import Path
r=Path(__file__).resolve().parents[2]
a=r/'macdir/Sources/MacdirCore/UpdateChecker.swift'
b=r/'ios/Sources/UpdateChecker.swift'
assert a.exists(), 'Missing native update checker'
# macOS 103 and iOS 102 intentionally differ only in their numeric identity.
mac = a.read_text()
ios = b.read_text()
assert mac.replace('public static let version = "1.0.3"', 'public static let version = "1.0.2"', 1).replace('public static let build = 103', 'public static let build = 102', 1) == ios, 'Apple update logic drift beyond version/build'
s=a.read_text()
assert 'https://coinlogy.github.io/diakitw/updates/v1.json' in s
assert '32 * 1024' in s and 'timeoutIntervalForResource = 10' in s
assert 'hash.utf8.count == 64' in s, 'Reject a trailing newline after 64 hex digits (regex $ alone is insufficient)'
assert 'completionHandler(nil)' in s and 'httpCookieStorage = nil' in s
assert 'UpdateMenu.shared' in (r/'macdir/Sources/macdir/main.swift').read_text()
assert 'UpdateSection' in (r/'ios/Sources/DiakitwApp.swift').read_text()
print('PASS: shared Apple source parity and native controls wiring (not UI runtime)')
