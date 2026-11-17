"""The next build must be 1.0.3 / 103 on every platform."""
import json
import plistlib
import re
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]

class Unified103Source(unittest.TestCase):
    def test_apple_bundle_versions(self):
        for platform in ('macdir','ios'):
            with (ROOT/platform/'Info.plist').open('rb') as f: p=plistlib.load(f)
            self.assertEqual((p['CFBundleShortVersionString'],int(p['CFBundleVersion'])),('1.0.3',103),platform)

    def test_android_package_version(self):
        text=(ROOT/'diakitw-android/app/build.gradle').read_text()
        self.assertRegex(text,r'\bversionCode\s+103\b')
        self.assertRegex(text,r'''\bversionName\s+['"]1\.0\.3['"]''')

    def test_desktop_package_versions(self):
        for path in ('diakitw-desktop/package.json','diakitw-desktop/app/package.json','diakitw-desktop/package-lock.json'):
            data=json.loads((ROOT/path).read_text())
            self.assertEqual(data['version'],'1.0.3',path)
        self.assertEqual(json.loads((ROOT/'diakitw-desktop/app/package.json').read_text())['build'],103)
        self.assertIn('diakitw 1.0.3',(ROOT/'diakitw-desktop/app/index.html').read_text())

    def test_shared_apple_update_identity(self):
        for path in ('macdir/Sources/MacdirCore/UpdateChecker.swift','ios/Sources/UpdateChecker.swift'):
            text=(ROOT/path).read_text()
            self.assertEqual(re.findall(r'public static let version = "([^"]+)"',text),['1.0.3','1.0.3'],path)
            self.assertEqual(re.findall(r'public static let build = (\d+)',text),['103','103'],path)

if __name__=='__main__':unittest.main()
