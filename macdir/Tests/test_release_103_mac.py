"""103 Mac candidate contract: toolbar, signing, packaging and CI."""
import importlib.util
import plistlib
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent

class Release103(unittest.TestCase):
    def test_toolbar_order_and_responsive_wrap(self):
        main = (ROOT / 'Sources/macdir/main.swift').read_text()
        toolbar = main.split('@ViewBuilder private var toolbarActions', 1)[1].split('Text(model.computerName)', 1)[0]
        labels = ['Тест интернета', 'Диагностика', 'Терминал', 'Мониторинг системы', 'Проверить кэши', 'Корень /', 'Выбрать папку']
        positions = [toolbar.index(label) for label in labels]
        self.assertEqual(positions, sorted(positions))
        self.assertIn('DesktopActions.shared.terminal()', toolbar)
        self.assertIn('DesktopActions.shared.processes()', toolbar)
        self.assertIn('ViewThatFits(in: .horizontal)', toolbar)
        self.assertIn('LazyVGrid', toolbar)
        self.assertIn('width >=', toolbar)
        self.assertIn('Button { model.choose() }', toolbar)
        self.assertIn('if model.scanning', toolbar)
        self.assertIn('if let volume = model.volume', toolbar)
        actions = (ROOT / 'Sources/macdir/DesktopActions.swift').read_text()
        self.assertIn('func addItems(to menu: NSMenu)', actions)

    def test_mac_identity_and_package(self):
        info = plistlib.loads((ROOT / 'Info.plist').read_bytes())
        self.assertEqual((info['CFBundleShortVersionString'], info['CFBundleVersion']), ('1.0.3', '103'))
        self.assertEqual(info['CFBundleIdentifier'], 'local.emcx.macdir')
        self.assertIn('.applicationVersion: "1.0.3"', (ROOT / 'Sources/macdir/main.swift').read_text())
        self.assertIn('diakitw 1.0.3 (103)', (ROOT / 'Sources/macdir/UpdateMenu.swift').read_text())
        checker = (ROOT / 'Sources/MacdirCore/UpdateChecker.swift').read_text()
        self.assertEqual(checker.count('public static let version = "1.0.3"'), 1)
        self.assertEqual(checker.count('public static let build = 103'), 1)
        self.assertIn('#else\n    public static let version = "1.0.2"\n    public static let build = 102', checker)
        spec = importlib.util.spec_from_file_location('packager', ROOT / 'package-diagnostics-dmg.py')
        packager = importlib.util.module_from_spec(spec); spec.loader.exec_module(packager)
        self.assertEqual((packager.VERSION, packager.BUILD), ('1.0.3', '103'))
        self.assertEqual(packager.artifact_paths(ROOT, 'arm64')['dmg'].name, 'diakitw-1.0.3-macos-arm64.dmg')
        self.assertTrue((ROOT / 'assets' / packager.README).is_file())

    def test_signing_and_notarization_fail_closed(self):
        build = (ROOT / 'build.sh').read_text()
        packaging = (ROOT / 'package-diagnostics-dmg.py').read_text()
        signing = (ROOT / 'sign-and-notarize.sh').read_text()
        workflow = (REPO / '.github/workflows/macos-build.yml').read_text()
        self.assertNotIn('codesign --force --sign -', build)
        self.assertNotIn("'codesign', '--force', '--sign', '-'", packaging)
        self.assertIn('Developer ID Application:', signing)
        self.assertIn('security find-identity', signing)
        self.assertIn('codesign --force --options runtime --timestamp --sign', signing)
        self.assertIn('notarytool submit', signing)
        self.assertIn('stapler staple', signing)
        self.assertIn('stapler validate', signing)
        self.assertIn('sign-and-notarize.sh preflight', build)
        self.assertIn('sign-and-notarize.sh sign', build)
        self.assertIn("ROOT / 'sign-and-notarize.sh', 'notarize', dmg", packaging)
        self.assertIn('Authority=Developer ID Application:', packaging)
        self.assertIn("'runtime'", packaging)
        self.assertIn('verify_developer_id(mounted)', packaging)
        self.assertIn('MACDIR_SIGNING_P12_BASE64', workflow)
        self.assertIn('MACDIR_NOTARY_KEY_BASE64', workflow)
        self.assertIn('macos-103-build-only', workflow)
        self.assertIn('diakitw-1.0.3-macos-arm64.dmg', workflow)
        self.assertNotIn('release create', workflow)

    def test_signature_metadata_rejects_adhoc_and_missing_runtime(self):
        from unittest.mock import patch
        spec = importlib.util.spec_from_file_location('packager', ROOT / 'package-diagnostics-dmg.py')
        packager = importlib.util.module_from_spec(spec); spec.loader.exec_module(packager)
        for metadata in ('flags=0x10000(runtime)\nSignature=adhoc',
                         'flags=0x0(none)\nAuthority=Developer ID Application: Fixture'):
            with patch.object(packager.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '', metadata)):
                with self.assertRaises(RuntimeError): packager.verify_developer_id('fixture.app')
        good = 'CodeDirectory v=20500 flags=0x10000(runtime)\nAuthority=Developer ID Application: Fixture'
        with patch.object(packager.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '', good)):
            packager.verify_developer_id('fixture.app')

    def test_no_unnotarized_zip_distribution(self):
        self.assertNotIn('ditto -c -k', (ROOT / 'build.sh').read_text())
        self.assertNotIn('ZipFile(', (ROOT / 'Tests/verify_ci_artifacts.py').read_text())

    def test_missing_credentials_cannot_start_build(self):
        env = {'PATH': '/usr/bin:/bin:/usr/sbin:/sbin', 'HOME': '/root'}
        result = subprocess.run(['bash', str(ROOT / 'sign-and-notarize.sh'), 'preflight'], env=env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Missing', result.stderr)

if __name__ == '__main__': unittest.main()
