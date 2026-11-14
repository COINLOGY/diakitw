import pathlib,unittest
R=pathlib.Path(__file__).resolve().parents[1]
class UpdatesWiring(unittest.TestCase):
 def test_updates_remain_foreground_manual_install_only(self):
  s=(R/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  for token in ['updates.start(', 'updates.stop()', 'updateFetch.cancel()', 'Updates.validURL(', 'Intent.ACTION_VIEW', 'Проверить обновления', 'Стабильный', 'Тестовый', 'Позже', 'Скачать', 'Установка вручную', 'updateNotice.setVisibility(View.GONE)', 'updates.complete(token']:
   self.assertIn(token,s)
  self.assertNotIn('REQUEST_INSTALL_PACKAGES',(R/'app/src/main/AndroidManifest.xml').read_text())
if __name__=='__main__':unittest.main()
