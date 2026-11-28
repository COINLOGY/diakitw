"""All candidate binaries must advertise one 1.1.1 / 111 identity."""
import json
import plistlib
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class Unified111Candidate(unittest.TestCase):
    def test_apple_bundle_versions(self):
        for platform in ("macdir", "ios"):
            with (ROOT / platform / "Info.plist").open("rb") as source:
                info = plistlib.load(source)
            self.assertEqual(
                (info["CFBundleShortVersionString"], int(info["CFBundleVersion"])),
                ("1.1.1", 111),
                platform,
            )

    def test_android_package_version(self):
        source = (ROOT / "diakitw-android/app/build.gradle").read_text()
        self.assertRegex(source, r"\bversionCode\s+111\b")
        self.assertRegex(source, r"\bversionName\s+['\"]1\.1\.1['\"]")

    def test_desktop_package_versions(self):
        for path in (
            "diakitw-desktop/package.json",
            "diakitw-desktop/app/package.json",
            "diakitw-desktop/package-lock.json",
        ):
            data = json.loads((ROOT / path).read_text())
            self.assertEqual(data["version"], "1.1.1", path)
        app = json.loads((ROOT / "diakitw-desktop/app/package.json").read_text())
        self.assertEqual(app["build"], 111)
        self.assertIn("diakitw 1.1.1", (ROOT / "diakitw-desktop/app/index.html").read_text())

    def test_apple_updater_versions_in_both_compile_branches(self):
        for path in (
            "macdir/Sources/MacdirCore/UpdateChecker.swift",
            "ios/Sources/UpdateChecker.swift",
        ):
            source = (ROOT / path).read_text()
            self.assertEqual(
                re.findall(r'public static let version = "([^"]+)"', source),
                ["1.1.1", "1.1.1"],
                path,
            )
            self.assertEqual(
                re.findall(r"public static let build = (\d+)", source),
                ["111", "111"],
                path,
            )

    def test_visible_platform_versions(self):
        expectations = {
            "macdir/Sources/macdir/main.swift": 'applicationVersion: "1.1.1"',
            "macdir/Sources/macdir/UpdateMenu.swift": 'diakitw 1.1.1 (111)',
            "ios/Sources/DiakitwApp.swift": '1.1.1 · iOS · build 111',
            "diakitw-android/app/src/main/java/app/diakitw/MainActivity.java": 'Обновления · 1.1.1 (111)',
            "diakitw-android/app/src/main/java/app/diakitw/SpeedReport.java": '"appVersion","1.1.1"',
            "macdir/package-diagnostics-dmg.py": "VERSION = '1.1.1'",
            "ios/Scripts/validate_project.py": "['CFBundleShortVersionString']=='1.1.1'",
        }
        for path, token in expectations.items():
            self.assertIn(token, (ROOT / path).read_text(), path)
        self.assertIn("'build',111", (ROOT / "diakitw-android/app/src/main/java/app/diakitw/SpeedReport.java").read_text().replace('"build",', "'build',"))
        package = (ROOT / "macdir/package-diagnostics-dmg.py").read_text()
        self.assertIn("BUILD = '111'", package)
        self.assertIn('README-diakitw-1.1.1-RU.txt', package)


if __name__ == "__main__":
    unittest.main()
