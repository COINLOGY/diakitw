import pathlib,unittest
R=pathlib.Path(__file__).resolve().parents[1]
class UpdatesWiring(unittest.TestCase):
 def test_updates_remain_foreground_manual_install_only(self):
  s=(R/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  for token in ['updates.start(', 'updates.stop()', 'updateFetch.cancel()', 'Updates.validURL(', 'Intent.ACTION_VIEW', 'Проверить обновления', 'Стабильный', 'Тестовый', 'Позже', 'Скачать', 'Установка вручную', 'updateNotice.setVisibility(View.GONE)', 'updates.complete(token']:
   self.assertIn(token,s)
  self.assertNotIn('REQUEST_INSTALL_PACKAGES',(R/'app/src/main/AndroidManifest.xml').read_text())
 def test_057_report_and_update_identity(self):
  gradle=(R/'app/build.gradle').read_text()
  report=(R/'app/src/main/java/app/diakitw/SpeedReport.java').read_text()
  activity=(R/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  updates=(R/'app/src/main/java/app/diakitw/Updates.java').read_text()
  self.assertIn("versionCode 57; versionName '0.5.7'",gradle)
  self.assertIn('"appVersion","0.5.7"',report)
  self.assertIn('"build",57',report)
  self.assertIn('diakitw 0.5.7 · ',report)
  self.assertIn('Обновления · 0.5.7 (57)',activity)
  self.assertIn('Обзор · diakitw 0.5.7',activity)
  self.assertIn('compare(v,"0.5.7")<=0||build<=57',updates)
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
