import pathlib,unittest
R=pathlib.Path(__file__).resolve().parents[1]
class UpdatesWiring(unittest.TestCase):
 def test_updates_foreground_verified_package_installer(self):
  s=(R/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  for token in ['updates.start(', 'updates.stop()', 'updateFetch.cancel()', 'Updates.validURL(', 'new Updates.Download()', 'verifyApkIdentity(', 'PackageInstaller.Session', 'Проверить обновления', 'Стабильный', 'Тестовый', 'Позже', 'Скачать', 'updateNotice.setVisibility(View.GONE)', 'updates.complete(token']:
   self.assertIn(token,s)
  self.assertIn('REQUEST_INSTALL_PACKAGES',(R/'app/src/main/AndroidManifest.xml').read_text())
 def test_057_report_and_update_identity(self):
  gradle=(R/'app/build.gradle').read_text()
  report=(R/'app/src/main/java/app/diakitw/SpeedReport.java').read_text()
  activity=(R/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  updates=(R/'app/src/main/java/app/diakitw/Updates.java').read_text()
  self.assertIn("versionCode 104; versionName '1.0.4'",gradle)
  self.assertIn('"appVersion","1.0.4"',report)
  self.assertIn('"build",104',report)
  self.assertIn('diakitw 1.0.4 · ',report)
  self.assertIn('Обновления · 1.0.4 (104)',activity)
  self.assertIn('Обзор · diakitw 1.0.4',activity)
  self.assertIn('compare(v,installedVersion)<=0||build<=installedBuild',updates)
 def test_debug_only_offline_arrow_probe_guard(self):
  activity=(R/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  probe=(R/'app/src/androidTest/java/app/diakitw/LayoutProbe.java').read_text()
  self.assertIn('diakitw.test.offline',activity)
  self.assertIn('ApplicationInfo.FLAG_DEBUGGABLE',activity)
  self.assertIn('diakitw.test.offline',probe)
  self.assertIn('"arrow".equals(mode)',probe)
  self.assertIn('if(!testOffline)',activity)
  self.assertIn('if(testOffline)return;',activity)
if __name__=='__main__':unittest.main()
