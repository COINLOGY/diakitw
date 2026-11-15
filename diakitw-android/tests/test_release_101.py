from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "diakitw-android/app"

class Release101(unittest.TestCase):
    def test_identity_and_rotated_feed(self):
        gradle = (APP / "build.gradle").read_text()
        updates = (APP / "src/main/java/app/diakitw/Updates.java").read_text()
        report = (APP / "src/main/java/app/diakitw/SpeedReport.java").read_text()
        activity = (APP / "src/main/java/app/diakitw/MainActivity.java").read_text()
        self.assertIn("versionCode 101; versionName '1.0.1'", gradle)
        self.assertIn("/updates/v2.json", updates)
        self.assertNotIn("/updates/v1.json", updates)
        self.assertIn('compare(v,installedVersion)<=0||build<=installedBuild', updates)
        self.assertIn('"appVersion","1.0.1"', report)
        self.assertIn('"build",101', report)
        self.assertIn('Обновления · 1.0.1 (101)', activity)
        self.assertIn('Обзор · diakitw 1.0.1', activity)

    def test_entry_probe_suppresses_all_background_network(self):
        probe = (APP / "src/androidTest/java/app/diakitw/LayoutProbe.java").read_text()
        self.assertIn('"arrow".equals(mode)||"entry".equals(mode)', probe)
        self.assertIn('launch.putExtra("diakitw.test.offline",true)', probe)

    def test_signed_release_candidate_workflow(self):
        workflow = (ROOT / ".github/workflows/android-release-101.yml").read_text()
        signer = (ROOT / "diakitw-android/ci/build-signed-101.sh").read_text()
        native = (ROOT / "diakitw-android/ci/run-android-entry.sh").read_text()
        for token in ("feat/release-101", "DIAKITW_ANDROID_P12_BASE64", "DIAKITW_ANDROID_P12_PASSWORD",
                      "persist-credentials: false", "contents: read", "api-level: 35"):
            self.assertIn(token, workflow)
        for token in ("diakitw-release-101", "d9298271dcb4e32856abdc2111b35ae43b7770b1c9fbfefa66100e899a58abc8",
                      "zipalign\" -c", "apksigner\" verify", "--ks-pass env:DIAKITW_ANDROID_P12_PASSWORD"):
            self.assertIn(token, signer)
        self.assertIn("-e mode entry", native)
        self.assertIn("Active default network: none", native)
        self.assertIn("script: bash diakitw-android/ci/run-android-entry.sh", workflow)
        self.assertIn("if-no-files-found: error", workflow)
        self.assertNotIn("path: diakitw-android/app/build/outputs/apk/release/", workflow)

if __name__ == "__main__": unittest.main()
