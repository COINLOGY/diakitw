from pathlib import Path
import re
import unittest

SRC = (Path(__file__).resolve().parents[1] / 'app/src/main/java/app/diakitw/MainActivity.java').read_text()

class AndroidProfileDeleteUI(unittest.TestCase):
    def test_delete_requires_explicit_confirmation_and_is_available_from_detail_and_editor(self):
        self.assertIn('button("Удалить профиль",v->confirmDeleteProfile(selectedProfile))', SRC)
        self.assertIn('button("Удалить профиль",v->confirmDeleteProfile(editing))', SRC)
        dialog = re.search(r'void confirmDeleteProfile\(String id\)\{(.*?)\n \}', SRC, re.S)
        self.assertIsNotNone(dialog)
        self.assertIn('new AlertDialog.Builder(this)', dialog.group(1))
        self.assertIn('setPositiveButton("Удалить"', dialog.group(1))
        self.assertIn('setNegativeButton("Отмена",null)', dialog.group(1))
        self.assertIn('deleteProfile(id)', dialog.group(1))

    def test_confirmed_delete_persists_and_returns_to_root(self):
        body = re.search(r'void deleteProfile\(String id\)\{(.*?)\n \}', SRC, re.S)
        self.assertIsNotNone(body)
        self.assertIn('Profiles.remove(sshProfiles,id)', body.group(1))
        self.assertIn('persistProfiles()', body.group(1))
        self.assertIn('selectedProfile=""', body.group(1))
        self.assertIn('showScreen("servers")', body.group(1))

class AndroidProfileDeleteCI(unittest.TestCase):
    def test_model_is_compiled_and_run_in_android_ci(self):
        ci = (Path(__file__).resolve().parents[1] / 'ci/run-update-tests.sh').read_text()
        self.assertIn('Profiles.java tests/ProfilesTest.java', ci)
        self.assertIn('app.diakitw.ProfilesTest', ci)

if __name__ == '__main__': unittest.main()
