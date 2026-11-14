"""Lightweight source gate; runtime behavior is tested by update_checks.swift in CI."""
from pathlib import Path
r=Path(__file__).resolve().parents[2]
a=r/'macdir/Sources/MacdirCore/UpdateChecker.swift'
b=r/'ios/Sources/UpdateChecker.swift'
assert a.exists(), 'Missing native update checker'
assert a.read_bytes()==b.read_bytes(), 'Apple update contract drift'
s=a.read_text()
assert 'https://coinlogy.github.io/diakitw/updates/v1.json' in s
assert '32 * 1024' in s and 'timeoutIntervalForResource = 10' in s
assert 'completionHandler(nil)' in s and 'httpCookieStorage = nil' in s
assert 'UpdateMenu.shared' in (r/'macdir/Sources/macdir/main.swift').read_text()
assert 'UpdateSection' in (r/'ios/Sources/DiakitwApp.swift').read_text()
print('PASS: shared Apple source parity and native controls wiring (not UI runtime)')
