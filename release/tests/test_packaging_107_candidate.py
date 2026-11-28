"""1.0.7 candidate packaging is versioned, build-only, and signer-safe."""
import unittest
from pathlib import Path

R = Path(__file__).resolve().parents[2]


class Packaging107(unittest.TestCase):
    def test_android_candidate_preserves_signer_and_native_probe(self):
        signed = (R / 'diakitw-android/ci/build-signed-107.sh').read_text()
        self.assertIn('diakitw-android-1.0.7.apk', signed)
        self.assertIn('diakitw-release-101', signed)
        self.assertIn('d9298271dcb4e32856abdc2111b35ae43b7770b1c9fbfefa66100e899a58abc8', signed)
        workflow = (R / '.github/workflows/android-release-107.yml').read_text()
        self.assertIn('feat/release-107-candidate', workflow)
        self.assertIn('build-signed-107.sh', workflow)
        self.assertIn('run-android-107.sh', workflow)
        self.assertIn('diakitw-android-1.0.7.apk', workflow)
        probe = (R / 'diakitw-android/ci/run-android-107.sh').read_text()
        self.assertIn('mode release107', probe)
        self.assertIn('PASS release107 offline resources, RX/TX, disk, map visible, folder grant gate', probe)
        self.assertIn('native-107-status.txt', probe)

    def test_desktop_portable_package_scripts_and_pe(self):
        scripts = R / 'diakitw-desktop/scripts'
        for name in ('build-v107.mjs', 'normalize-pe-v107.mjs', 'verify-bundles-v107.mjs',
                     'archive-v107.py', 'verify-archives-v107.py'):
            self.assertIn('1.0.7', (scripts / name).read_text(), name)
        self.assertIn('bundles-v107', (scripts / 'verify-upstream-v107.py').read_text())
        archive = (scripts / 'archive-v107.py').read_text()
        self.assertIn('README-CANDIDATE.txt', archive)
        self.assertIn('неподписан', archive)
        pe = (scripts / 'normalize-pe-v107.mjs').read_text()
        self.assertIn('version.setFileVersion(1,0,7,107,0)', pe)
        self.assertIn('(7<<16)|107', pe)
        workflow = (R / '.github/workflows/desktop-107-candidate.yml').read_text()
        self.assertIn('feat/release-107-candidate', workflow)
        self.assertIn('diakitw-1.0.7-windows-x64.zip', workflow)
        self.assertIn('diakitw-1.0.7-linux-x64.tar.gz', workflow)

    def test_apple_candidate_paths(self):
        mac = (R / '.github/workflows/macos-build-107.yml').read_text()
        self.assertIn('macOS 1.0.7 build-only', mac)
        self.assertIn('diakitw-1.0.7-macos-unsigned-arm64.dmg', mac)
        self.assertIn('diakitw-1.0.7-macos-unsigned-x86_64.dmg', mac)
        self.assertIn('MACDIR_SIGNING_MODE', mac)
        self.assertNotIn('release create', mac)
        self.assertIn('diakitw-1.0.7', (R / 'macdir/ci-build.sh').read_text())
        self.assertIn("'build': '107'", (R / 'macdir/Tests/verify_ci_artifacts.py').read_text())
        ios = (R / '.github/workflows/ios-build-107.yml').read_text()
        self.assertIn('feat/release-107-candidate', ios)
        self.assertNotIn('upload-artifact@', ios)
        self.assertIn('diakitw-1.0.7-ios-', (R / 'ios/Scripts/ci-build.sh').read_text())
    def test_new_apple_workflows_run_builds_on_candidate_push(self):
        mac = (R / '.github/workflows/macos-build-107.yml').read_text()
        ios = (R / '.github/workflows/ios-build-107.yml').read_text()
        self.assertIn('branches: [feat/release-107-candidate]', mac)
        self.assertIn("github.event_name == 'push' || inputs.scope == 'unsigned'", mac)
        self.assertIn('".github/workflows/ios-build-107.yml"', ios)

    def test_apple_layout_contracts_run_in_native_ci(self):
        self.assertIn('python3 Tests/check_release107_mac_layout.py', (R / 'macdir/build.sh').read_text())
        self.assertIn('python3 Tests/test_layout_104.py', (R / 'ios/Scripts/ci-build.sh').read_text())
        self.assertIn('Tests/counter_checks.swift', (R / 'ios/Scripts/ci-build.sh').read_text())

    def test_feed_gate_routes_new_source_to_107_tests(self):
        source = (R / '.github/workflows/feed-validation.yml').read_text()
        self.assertIn("['CFBundleShortVersionString'] == '1.0.7'", source)
        self.assertIn('release/tests/test_unified_107_candidate.py', source)
        self.assertIn('release/tests/test_packaging_107_candidate.py', source)
        self.assertIn('macdir/Tests/test_country_flag_status.py', source)


if __name__ == '__main__':
    unittest.main()
