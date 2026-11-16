from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
NEW_SHA = '762e6711a3574dcc1d4313cd242db07cc713e104ad3629cc3d57634285a7d190'
OLD_SHA = '5a8b72b229ef0769639eef112ec303bb585bc87963a53f4807d358d157808aa2'

class Android103ReplacementPublication(unittest.TestCase):
    def test_all_publication_surfaces_use_replacement_apk_digest(self):
        for path in ('README.md', 'manifest.json', 'updates/v2.json'):
            text = (ROOT / path).read_text()
            with self.subTest(path=path):
                self.assertIn(NEW_SHA, text)
                self.assertNotIn(OLD_SHA, text)

if __name__ == '__main__': unittest.main()
