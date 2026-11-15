from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'app/src/main/java/app/diakitw'

class AutoInstallWiring(unittest.TestCase):
    def test_offer_triggers_download_and_package_installer_only_after_signer_check(self):
        activity = (SRC/'MainActivity.java').read_text()
        self.assertIn('new Updates.Download()', activity)
        self.assertIn('verifyApkIdentity(', activity)
        self.assertIn('PackageInstaller.Session', activity)
        self.assertIn('PackageInstaller.STATUS_PENDING_USER_ACTION', (SRC/'UpdateInstallReceiver.java').read_text())
        self.assertIn('Intent.EXTRA_INTENT', (SRC/'UpdateInstallReceiver.java').read_text())
        self.assertNotIn('ACTION_VIEW,Uri.parse(offer.url)', activity)

    def test_api26_27_identity_uses_legacy_fields_only(self):
        activity = (SRC/'MainActivity.java').read_text()
        self.assertIn('Build.VERSION.SDK_INT>=28?PackageManager.GET_SIGNING_CERTIFICATES:PackageManager.GET_SIGNATURES', activity)
        self.assertIn('Build.VERSION.SDK_INT>=28?info.getLongVersionCode():info.versionCode', activity)
        self.assertIn('Build.VERSION.SDK_INT>=28?info.signingInfo.getApkContentsSigners():info.signatures', activity)
        self.assertIn('Build.VERSION.SDK_INT>=28&&(info.signingInfo==null||info.signingInfo.hasMultipleSigners())', activity)
        self.assertIn('archiveVersion(archive)', activity)
        self.assertIn('archiveVersion(installed)', activity)

    def test_installed_build_is_passed_into_feed_selection(self):
        activity = (SRC/'MainActivity.java').read_text()
        self.assertIn('Updates.select(run.run(),channel,BuildConfig.VERSION_NAME,BuildConfig.VERSION_CODE)', activity)

    def test_version_constants_are_generated_by_android_gradle(self):
        gradle = (ROOT/'app/build.gradle').read_text()
        self.assertIn('buildFeatures { buildConfig true }', gradle)

    def test_install_permission_and_receiver_are_explicit(self):
        manifest = (ROOT/'app/src/main/AndroidManifest.xml').read_text()
        self.assertIn('android.permission.REQUEST_INSTALL_PACKAGES', manifest)
        self.assertIn('android:exported="false"', manifest)
        self.assertIn('.UpdateInstallReceiver', manifest)

    def test_self_update_requests_no_user_action_only_when_supported_and_handles_fallback(self):
        activity = (SRC/'MainActivity.java').read_text()
        receiver = (SRC/'UpdateInstallReceiver.java').read_text()
        manifest = (ROOT/'app/src/main/AndroidManifest.xml').read_text()
        self.assertIn('android.permission.UPDATE_PACKAGES_WITHOUT_USER_ACTION', manifest)
        self.assertIn('Build.VERSION.SDK_INT>=31', activity)
        self.assertIn('archive.applicationInfo.targetSdkVersion', activity)
        self.assertIn('params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)', activity)
        self.assertIn('PackageInstaller.STATUS_PENDING_USER_ACTION', receiver)
        self.assertIn('context.startActivity(confirmation)', receiver)

if __name__ == '__main__': unittest.main()
