"""Unified 1.0.1 (57) source contract; publication feed is gated separately."""
from pathlib import Path
import json
import plistlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
VERSION = '1.0.1'
BUILD = 101

class Unified101SourceVersion(unittest.TestCase):
    def test_apple_bundle_versions(self):
        for name in ('macdir', 'ios'):
            with (ROOT / name / 'Info.plist').open('rb') as f:
                info = plistlib.load(f)
            self.assertEqual(info['CFBundleShortVersionString'], VERSION, name)
            self.assertEqual(int(info['CFBundleVersion']), BUILD, name)

    def test_desktop_package_versions(self):
        for name in ('diakitw-desktop/package.json', 'diakitw-desktop/app/package.json'):
            info = json.loads((ROOT / name).read_text())
            self.assertEqual(info['version'], VERSION, name)
            if 'displayVersion' in info:
                self.assertEqual(info['displayVersion'], VERSION, name)

    def test_android_package_version(self):
        text = (ROOT / 'diakitw-android/app/build.gradle').read_text()
        self.assertRegex(text, r'\bversionCode\s+101\b')
        self.assertRegex(text, r"\bversionName\s+['\"]1\.0\.1['\"]")

    def test_shared_apple_checker_is_current_for_both_platforms(self):
        text = (ROOT / 'macdir/Sources/MacdirCore/UpdateChecker.swift').read_text()
        versions = re.findall(r'public static let version = "([^"]+)"', text)
        builds = re.findall(r'public static let build = (\d+)', text)
        self.assertEqual(versions, [VERSION, VERSION])
        self.assertEqual(builds, [str(BUILD), str(BUILD)])

if __name__ == '__main__':
    unittest.main()
