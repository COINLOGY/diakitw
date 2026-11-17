from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
ANDROID = ROOT / 'diakitw-android'

class Release105(unittest.TestCase):
    def test_current_version_on_all_android_user_surfaces(self):
        gradle = (ANDROID / 'app/build.gradle').read_text()
        activity = (ANDROID / 'app/src/main/java/app/diakitw/MainActivity.java').read_text()
        report = (ANDROID / 'app/src/main/java/app/diakitw/SpeedReport.java').read_text()
        self.assertIn("versionCode 105; versionName '1.0.5'", gradle)
        self.assertIn('Обновления · 1.0.5 (105)', activity)
        self.assertIn('Обзор · diakitw 1.0.5', activity)
        for text in ('diakitw 1.0.5 · ', '"appVersion","1.0.5"', '"build",105'):
            self.assertIn(text, report)

    def test_signed_candidate_keeps_identity_and_fails_closed(self):
        script = (ANDROID / 'ci/build-signed-105.sh').read_text()
        self.assertIn('diakitw-android-1.0.5.apk', script)
        self.assertIn('diakitw-release-101', script)
        self.assertIn('d9298271dcb4e32856abdc2111b35ae43b7770b1c9fbfefa66100e899a58abc8', script)
        for requirement in ('DIAKITW_ANDROID_P12_BASE64', 'DIAKITW_ANDROID_P12_PASSWORD', 'zipalign" -c', 'apksigner" verify'):
            self.assertIn(requirement, script)
        self.assertNotIn('keytool -genkey', script)

    def test_candidate_ci_executes_offline_native_105_on_candidate_branch_only(self):
        workflow = (ROOT / '.github/workflows/android-release-105.yml').read_text()
        runner = (ANDROID / 'ci/run-android-105.sh').read_text()
        probe = (ANDROID / 'app/src/androidTest/java/app/diakitw/LayoutProbe.java').read_text()
        for text in ('feat/release-105-candidate', 'contents: read', 'persist-credentials: false', 'packages: platform-tools', 'build-signed-105.sh', 'run-android-105.sh', 'diakitw-android-1.0.5.apk', 'native-105-status.txt', 'if-no-files-found: error'):
            self.assertIn(text, workflow)
        self.assertNotIn('release create', workflow)
        for text in ('Active default network: none', 'ip link set "$iface" down', '-e mode release105', '-e mode entry', 'safe-probe-summary.py', 'native-105-status.txt'):
            self.assertIn(text, runner)
        self.assertIn('"release105".equals(mode)', probe)
        self.assertIn('diakitw.test.offline', probe)
        self.assertIn('adb shell settings put system font_scale 1.0', runner)
        self.assertLess(runner.index('for variant in portrait landscape large-font'), runner.index('adb shell settings put system font_scale 1.0\ncheck_offline'))
        self.assertIn('Обновления · 1.0.5 (105)', probe)
        self.assertIn('PASS release105 offline', probe)
        self.assertIn('SAFE_FRAME app.diakitw.', probe)
        self.assertIn('p.inspect(root,new Rect(xy[0],xy[1],xy[0]+root.getWidth(),xy[1]+root.getHeight()),true)', (ANDROID / 'app/src/androidTest/java/app/diakitw/EntryProbe.java').read_text())
        self.assertIn('if(typical&&!allowScroll)', probe)
        self.assertIn('Touch target <48dp: class=', probe)
        main = (ANDROID / 'app/src/main/java/app/diakitw/MainActivity.java').read_text()
        self.assertIn('Metric(String name){\n   super(MainActivity.this);this.name=name;setMinimumHeight(dp(48));', main)
        self.assertGreater(main.index('geo.addView(summary,new LinearLayout.LayoutParams(-1,-2))'), main.index('geo.addView(persistentMap,new LinearLayout.LayoutParams'))
        self.assertIn('a.summary.requestRectangleOnScreen(', (ANDROID / 'app/src/androidTest/java/app/diakitw/EntryProbe.java').read_text())
        self.assertIn('Entry map hidden', (ANDROID / 'app/src/androidTest/java/app/diakitw/EntryProbe.java').read_text())
        self.assertIn('a.persistentMap.getHeight()*(a.landscape?.5:.75),"Map hidden below initial viewport visible="', probe)

    def test_safe_failure_summary_has_allowlisted_line_not_ip(self):
        import subprocess, sys, tempfile
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / 'probe.txt'
            report.write_text('FAIL java.lang.AssertionError: Touch target <48dp: class=Button size=42x36 id=-1 IP=2001:db8::1\nSAFE_FRAME app.diakitw.LayoutProbe(LayoutProbe.java:52)\nSAFE_FRAME app.diakitw.EntryProbe(EntryProbe.java:23)\n')
            result = subprocess.run([sys.executable, str(ANDROID / 'ci/safe-probe-summary.py'), str(report)], capture_output=True, text=True, check=True)
            self.assertIn('EntryProbe.java:23', result.stdout)
            self.assertIn('LayoutProbe.java:52', result.stdout)
            self.assertIn('code=touch-small', result.stdout)
            self.assertIn('touch=Button:42x36:id=-1', result.stdout)
            self.assertNotIn('2001:db8::1', result.stdout)

if __name__ == '__main__': unittest.main()
