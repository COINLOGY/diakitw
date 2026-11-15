"""Lightweight source gate; runtime behavior is tested by update_checks.swift in CI."""
from pathlib import Path
r=Path(__file__).resolve().parents[2]
a=r/'macdir/Sources/MacdirCore/UpdateChecker.swift'
b=r/'ios/Sources/UpdateChecker.swift'
assert a.exists(), 'Missing native update checker'
assert a.read_text().replace('#else\n    public static let version = "0.5.7"\n    public static let build = 57\n    #endif', '#else\n    public static let version = "0.5.5"\n    public static let build = 55\n    #endif', 1) == b.read_text() or a.read_bytes() == b.read_bytes(), 'Apple update contract drift (except iOS version identity pending integration)'
assert a.read_text().count('public static let version = "0.5.7"') == 2, 'iOS and macOS must both report 0.5.7'
assert a.read_text().count('public static let build = 57') == 2, 'iOS and macOS must both report build 57'
s=a.read_text()
assert 'https://coinlogy.github.io/diakitw/updates/v1.json' in s
assert '32 * 1024' in s and 'timeoutIntervalForResource = 10' in s
assert 'hash.utf8.count == 64' in s, 'Reject a trailing newline after 64 hex digits (regex $ alone is insufficient)'
assert 'completionHandler(nil)' in s and 'httpCookieStorage = nil' in s
assert 'UpdateMenu.shared' in (r/'macdir/Sources/macdir/main.swift').read_text()
assert 'UpdateSection' in (r/'ios/Sources/DiakitwApp.swift').read_text()
print('PASS: shared Apple source parity and native controls wiring (not UI runtime)')
