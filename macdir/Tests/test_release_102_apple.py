"""Apple build-only candidate identity and honest updater gate."""
from pathlib import Path
import plistlib

r = Path(__file__).resolve().parents[2]
mac = r / 'macdir'
ios = r / 'ios'
for root in (mac, ios):
    info = plistlib.loads((root / 'Info.plist').read_bytes())
    assert (info['CFBundleShortVersionString'], info['CFBundleVersion']) == ('1.0.2', '102')
    checker = root / ('Sources/MacdirCore/UpdateChecker.swift' if root == mac else 'Sources/UpdateChecker.swift')
    source = checker.read_text()
    assert source.count('public static let version = "1.0.2"') == 2
    assert source.count('public static let build = 102') == 2
assert (mac / 'Sources/MacdirCore/UpdateChecker.swift').read_bytes() == (ios / 'Sources/UpdateChecker.swift').read_bytes()
assert '.applicationVersion: "1.0.2"' in (mac / 'Sources/macdir/main.swift').read_text()
assert 'diakitw 1.0.2 (102)' in (mac / 'Sources/macdir/UpdateMenu.swift').read_text()
assert '1.0.2 · iOS · build 102' in (ios / 'Sources/DiakitwApp.swift').read_text()
assert (ios / 'diakitw.xcodeproj/project.pbxproj').read_text().count('MARKETING_VERSION = 1.0.2;CURRENT_PROJECT_VERSION = 102;') == 2
assert "VERSION = '1.0.2'" in (mac / 'package-diagnostics-dmg.py').read_text()
assert "BUILD = '102'" in (mac / 'package-diagnostics-dmg.py').read_text()
for path in ('macdir/build.sh', 'macdir/ci-build.sh', 'ios/Scripts/ci-build.sh', '.github/workflows/macos-build.yml', '.github/workflows/ios-build.yml'):
    text = (r / path).read_text()
    assert '1.0.2' in text and '0.5.7' not in text, path
assert 'CODE_SIGNING_ALLOWED=NO' in (ios / 'Scripts/ci-build.sh').read_text()
assert 'codesign --force --sign -' in (mac / 'build.sh').read_text()
assert 'Скачать в браузере' in (mac / 'Sources/macdir/UpdateMenu.swift').read_text()
assert 'Открыть страницу релиза' in (ios / 'Sources/UpdateSection.swift').read_text()
print('PASS Apple 1.0.2/102 identity, parity and browser-only unsigned/ad-hoc paths')
