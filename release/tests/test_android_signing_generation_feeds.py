"""The new Android certificate must never be offered to legacy v1 clients."""
import json
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class AndroidSigningGenerationFeeds(unittest.TestCase):
    def test_old_android_stays_on_v1_feed(self):
        feed=json.loads((ROOT/'updates/v1.json').read_text())
        android=[(r['version'],r['build']) for r in feed['releases'] if 'android' in r['assets']]
        self.assertEqual(android,[('0.5.5',55)])

    def test_new_android_uses_separate_v2_feed(self):
        self.assertTrue((ROOT/'updates/v2.json').is_file(), 'v2 feed must exist')
        feed=json.loads((ROOT/'updates/v2.json').read_text())
        self.assertEqual(feed['schema'],1)
        self.assertTrue(all(set(r['assets'])=={'android'} and r['build']>=101 for r in feed['releases']))
        source=(ROOT/'diakitw-android/app/src/main/java/app/diakitw/Updates.java').read_text()
        self.assertIn('updates/v2.json',source)
        self.assertNotIn('updates/v1.json',source)

    def test_android_java_feed_gate_uses_installed_identity(self):
        source=(ROOT/'release/FeedCheck.java').read_text()
        workflow=(ROOT/'.github/workflows/feed-validation.yml').read_text()
        self.assertIn('Updates.select(text,"preview",installedVersion,installedBuild)',source)
        self.assertIn('old-fixture',workflow)
        self.assertNotIn('.ci-scratch/Updates.java',workflow)

if __name__=='__main__': unittest.main()
