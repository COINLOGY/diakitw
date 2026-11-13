from pathlib import Path
r=Path(__file__).resolve().parents[1]
m=(r/'Sources/macdir/main.swift').read_text()
assert 'EgressLocation' in m, 'geo location not integrated'
assert 'GeoLookup.fetch()' in m
assert 'identityRequest?.cancel()' in m
assert 'DesktopActions.shared.addItems(to: appMenu)' in m
assert 'DesktopActions.shared.addItems(to: menu)' in (r/'Sources/macdir/ResourceHUD.swift').read_text()
assert 'Button("Карта")' in m and 'не GPS' in m
s=(r/'Sources/macdir/GeoLookup.swift').read_text()
for text in ['16384', 'bytes(from:', 'invalidateAndCancel()', 'completionHandler(nil)', 'timeoutIntervalForResource = 8', 'httpCookieStorage = nil', 'urlCredentialStorage = nil']:
 assert text in s, text
for text in ['2ip', 'EMCx', '300', '9000', '1 ч', '60 с']:
 assert text in m, text
print('PASS geo/menus lifecycle source wiring (not live network evidence)')
