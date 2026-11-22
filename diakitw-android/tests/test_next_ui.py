from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent
SRC = (ROOT.parent / 'app/src/main/java/app/diakitw/MainActivity.java').read_text()

class NextAndroidUI(unittest.TestCase):
    def test_distinct_navigation_and_real_speed_flow(self):
        self.assertIn('void showScreen(String screen)', SRC)
        self.assertIn('openTestPage()', SRC)
        self.assertIn('void openTest(){', SRC)
        self.assertIn('SpeedTest run=new SpeedTest()', SRC)
        self.assertIn('testPage?dm.widthPixels:', SRC)
        self.assertIn('setOnDismissListener(d->{stopTest()', SRC)

    def test_servers_root_and_child_use_only_unknown_metrics(self):
        self.assertIn('void renderServers()', SRC)
        self.assertIn('Все серверы', SRC)
        self.assertIn('CPU · Н/Д', SRC)
        self.assertIn('RAM · Н/Д', SRC)
        self.assertIn('SWAP · Н/Д', SRC)
        self.assertIn('Диск · Н/Д', SRC)
        self.assertIn('SSH-мониторинг недоступен', SRC)
        self.assertNotIn('28%', SRC)

    def test_profile_editor_validation_and_no_secret_persistence(self):
        self.assertIn('void editProfile(', SRC)
        self.assertIn('void saveProfile(', SRC)
        self.assertIn('SSH-порт', SRC)
        self.assertIn('IP или домен', SRC)
        self.assertIn('Пароль (не сохраняется)', SRC)
        self.assertIn('Ключ (не сохраняется)', SRC)
        self.assertIn('port<1||port>65535', SRC)
        self.assertIn('getPreferences(MODE_PRIVATE)', SRC)
        self.assertIn('putString("sshProfiles"', SRC)
        self.assertNotIn('putString("password"', SRC)
        self.assertNotIn('putString("key"', SRC)

    def test_battery_removed_and_compact_overview(self):
        self.assertNotIn('расход батареи', SRC)
        self.assertIn('persistentMap=new MapView', SRC)
        self.assertIn('dp(landscape?110:145)', SRC)

if __name__ == '__main__': unittest.main()
