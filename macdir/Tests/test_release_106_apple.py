"""Apple build-only candidate identity and honest updater gate."""
from pathlib import Path
import plistlib

r = Path(__file__).resolve().parents[2]
mac = r / 'macdir'
ios = r / 'ios'
for root in (ios,):
    info = plistlib.loads((root / 'Info.plist').read_bytes())
    assert (info['CFBundleShortVersionString'], info['CFBundleVersion']) == ('1.0.6', '106')
    checker = root / ('Sources/MacdirCore/UpdateChecker.swift' if root == mac else 'Sources/UpdateChecker.swift')
    source = checker.read_text()
    assert source.count('public static let version = "1.0.6"') == 2
    assert source.count('public static let build = 106') == 2
assert 'public static let version = "1.0.6"' in (mac / 'Sources/MacdirCore/UpdateChecker.swift').read_text()
assert '.applicationVersion: "1.0.6"' in (mac / 'Sources/macdir/main.swift').read_text()
assert 'diakitw 1.0.6 (106)' in (mac / 'Sources/macdir/UpdateMenu.swift').read_text()
assert '1.0.6 · iOS · build 106' in (ios / 'Sources/DiakitwApp.swift').read_text()
assert (ios / 'diakitw.xcodeproj/project.pbxproj').read_text().count('MARKETING_VERSION = 1.0.6;CURRENT_PROJECT_VERSION = 106;') == 2
assert "VERSION = '1.0.6'" in (mac / 'package-diagnostics-dmg.py').read_text()
assert "BUILD = '106'" in (mac / 'package-diagnostics-dmg.py').read_text()
assert "'build': '106'" in (mac / 'Tests/verify_ci_artifacts.py').read_text()
for path in ('ios/Scripts/ci-build.sh', '.github/workflows/ios-build-106.yml'):
    text = (r / path).read_text()
    assert '1.0.6' in text and '0.5.7' not in text, path
assert 'CODE_SIGNING_ALLOWED=NO' in (ios / 'Scripts/ci-build.sh').read_text()
assert 'codesign --force --sign -' not in (mac / 'build.sh').read_text()
assert 'Скачать в браузере' in (mac / 'Sources/macdir/UpdateMenu.swift').read_text()
assert 'Открыть страницу релиза' in (ios / 'Sources/UpdateSection.swift').read_text()
print('PASS unified Apple 1.0.6/106 identity')
