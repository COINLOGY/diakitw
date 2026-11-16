"""Guard the public 1.0.3 entrypoints and update feeds against drift."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERSION, BUILD = '1.0.3', 103
BASE = 'https://github.com/COINLOGY/diakitw/releases/download/v1.0.3/'
KEYS = {'mac-silicon': 'macos-arm64', 'mac-intel': 'macos-x86_64',
        'android': 'android', 'windows': 'windows-x64', 'linux': 'linux-x64'}


class Publication103(unittest.TestCase):
    def test_surfaces_and_feeds_match(self):
        manifest = json.loads((ROOT / 'manifest.json').read_text())
        readme = (ROOT / 'README.md').read_text()
        page = (ROOT / 'index.html').read_text()
        v1 = json.loads((ROOT / 'updates/v1.json').read_text())
        v2 = json.loads((ROOT / 'updates/v2.json').read_text())
        self.assertTrue(manifest['published'] and manifest['prerelease'])
        self.assertIn(VERSION, manifest['release'])
        self.assertEqual([p['id'] for p in manifest['platforms']], list(KEYS))
        self.assertIn('v1.0.3', readme)
        self.assertIn('v1.0.3', page)
        self.assertIn('1.0.3', (ROOT / 'release/1.0.3.md').read_text())
        self.assertEqual((v1['releases'][0]['version'], v1['releases'][0]['build'], v1['releases'][0]['channel']),
                         (VERSION, BUILD, 'preview'))
        self.assertEqual((v2['releases'][0]['version'], v2['releases'][0]['build'], v2['releases'][0]['channel']),
                         (VERSION, BUILD, 'preview'))
        self.assertEqual(set(v1['releases'][0]['assets']), set(KEYS.values()) - {'android'})
        self.assertEqual(set(v2['releases'][0]['assets']), {'android'})
        self.assertEqual([(r['version'], r['build']) for r in v1['releases'] if 'android' in r['assets']], [('0.5.5', 55)])
        self.assertEqual([r['version'] for r in v1['releases'][1:3]], ['1.0.2', '1.0.1'])
        self.assertEqual([r['version'] for r in v2['releases'][1:3]], ['1.0.2', '1.0.1'])
        for p in manifest['platforms']:
            pid = p['id']
            self.assertEqual((p['version'], p['displayVersion'], p['build']), (VERSION, VERSION, BUILD))
            self.assertEqual(p['url'], BASE + p['filename'])
            self.assertRegex(p['sha256'], r'^[a-f0-9]{64}$')
            self.assertGreater(p['size_bytes'], 0)
            self.assertTrue(any(f'[{p["filename"]}]({p["url"]})' in line and p['sha256'] in line
                                for line in readme.splitlines()), pid)
            feed = v2 if pid == 'android' else v1
            a = feed['releases'][0]['assets'][KEYS[pid]]
            expected_url = p['url'].replace('-macos-unsigned-', '-macos-')
            self.assertEqual((a['url'], a['size'], a['sha256']),
                             (expected_url, p['size_bytes'], p['sha256']), pid)
        combined = readme.lower() + page.lower() + json.dumps(manifest).lower()
        self.assertNotIn('1.0.3-ios-', combined)
        self.assertNotIn('actions/upload-artifact@', (ROOT / '.github/workflows/ios-build.yml').read_text())
        self.assertIn('Gatekeeper', readme)
        self.assertIn('SmartScreen', readme)


if __name__ == '__main__':
    unittest.main()
