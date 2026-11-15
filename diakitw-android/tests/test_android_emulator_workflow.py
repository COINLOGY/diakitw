"""Guard against an Android candidate CI that reports success without running native layout checks."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / '.github/workflows/android-layout-candidate.yml'

class AndroidLayoutWorkflow(unittest.TestCase):
    def test_branch_bound_and_read_only(self):
        text = WORKFLOW.read_text()
        self.assertIn("github.ref == 'refs/heads/feat/release-057-android'", text)
        self.assertIn('contents: read', text)
        self.assertIn('persist-credentials: false', text)
        self.assertIn('api-level: 35', text)
        self.assertIn('packages: platform-tools', text)
        self.assertIn('log-accepted-android-sdk-licenses: false', text)
        self.assertIn('gradle/actions/setup-gradle@748248ddd2a24f49513d8f472f81c3a07d4d50e1', text)
        self.assertIn('ReactiveCircus/android-emulator-runner@1dcd0090116d15e7c562f8db72807de5e036a4ed', text)
    def test_native_probe_exit_and_screenshots_are_required(self):
        text = WORKFLOW.read_text()
        self.assertIn('script: bash diakitw-android/ci/run-android-layout.sh', text)
        script = (ROOT / 'diakitw-android/ci/run-android-layout.sh').read_text()
        for value in ('app.diakitw.test/app.diakitw.LayoutProbe', '-e mode arrow',
                      'INSTRUMENTATION_CODE: -1', 'PASS network arrow native bounds',
                      'svc wifi disable', 'svc data disable',
                      'dumpsys connectivity', 'Active default network:',
                      'run-as app.diakitw cat cache/047-speed-idle.png'):
            self.assertIn(value, script)
        self.assertNotIn('am broadcast -a android.intent.action.AIRPLANE_MODE', script)
        self.assertIn('probe diagnostics:', script)
        self.assertIn('adb root', script)
        self.assertIn('cmd connectivity airplane-mode enable', script)
        self.assertIn('if-no-files-found: error', text)
        self.assertNotIn('continue-on-error: true', text)
    def test_uploaded_screenshot_contains_only_gauge_views(self):
        probe = (ROOT / 'diakitw-android/app/src/androidTest/java/app/diakitw/LayoutProbe.java').read_text()
        self.assertIn('screenshotSpeedDials(decor,"047-speed-idle")', probe)
        self.assertIn('if(v instanceof MainActivity.SpeedDial)', probe)
        self.assertIn('d.draw(canvas)', probe)
        self.assertNotIn('Bitmap.createBitmap(bitmap,', probe)
        self.assertNotIn('screenshot("047-speed-idle")', probe)
    def test_arrow_probe_never_starts_paid_speed_worker(self):
        probe = (ROOT / 'diakitw-android/app/src/androidTest/java/app/diakitw/LayoutProbe.java').read_text()
        method = probe.split('void arrowLayout(',1)[1].split('void compactSpeed(',1)[0]
        self.assertIn('screenshotSpeedDials(decor,"047-speed-idle")', method)
        self.assertIn('secondary(decor)', method)
        self.assertNotIn('performClick()', method)
        self.assertIn('"arrow".equals(mode)', probe)
        self.assertIn('launch.putExtra("diakitw.test.offline",true)', probe)

if __name__ == '__main__':
    unittest.main()
