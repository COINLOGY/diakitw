"""Public 1.0.2 source parity and signing-generation isolation."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = 'https://github.com/COINLOGY/diakitw/releases/download/v1.0.2/'
EXPECTED = {
    'mac-silicon': ('macos-arm64', 'diakitw-1.0.2-macos-arm64.dmg', 1612723, '9a95e993bbee821d638f5851cb1502e5f8f46987a61231feaa36f3d91b0dd1e1'),
    'mac-intel': ('macos-x86_64', 'diakitw-1.0.2-macos-x86_64.dmg', 1726649, '30e298b80bd52c9c20a6e4ca368a7a4ce275699c9d879310aa79c01956a7058e'),
    'android': ('android', 'diakitw-android-1.0.2.apk', 123663, '0952d1526845213e1dffc1217e507f758202631cfdd01fb2e687120981f6254e'),
    'windows': ('windows-x64', 'diakitw-1.0.2-windows-x64.zip', 158111881, 'c73c00f1faab320708cdfb5e57520d97a4ed2914953696e1b4017646b546ae16'),
    'linux': ('linux-x64', 'diakitw-1.0.2-linux-x64.tar.gz', 124049478, '6cc5be86588eebd75a4bf4ef195841727611b30c83a9a9ab17de7d5c5f638c74'),
}

class Publication102(unittest.TestCase):
    def test_surfaces_and_feed_match_assets(self):
        manifest = json.loads((ROOT/'manifest.json').read_text())
        readme = (ROOT/'README.md').read_text()
        page = (ROOT/'index.html').read_text()
        self.assertTrue(manifest['published'] and manifest['prerelease'])
        self.assertIn('1.0.2', manifest['release'])
        self.assertEqual([p['id'] for p in manifest['platforms']], list(EXPECTED))
        v1 = json.loads((ROOT/'updates/v1.json').read_text())
        v2 = json.loads((ROOT/'updates/v2.json').read_text())
        self.assertEqual((v1['releases'][0]['version'], v1['releases'][0]['build'], v1['releases'][0]['channel']), ('1.0.2', 102, 'preview'))
        self.assertEqual((v2['releases'][0]['version'], v2['releases'][0]['build'], v2['releases'][0]['channel']), ('1.0.2', 102, 'preview'))
        for p in manifest['platforms']:
            key, name, size, digest = EXPECTED[p['id']]
            self.assertEqual((p['version'], p['displayVersion'], p['build'], p['filename'], p['size_bytes'], p['sha256'], p['url']), ('1.0.2','1.0.2',102,name,size,digest,BASE+name))
            self.assertTrue(any(f'[{name}]({BASE+name})' in line and digest in line for line in readme.splitlines()))
            feed = v2 if p['id']=='android' else v1
            self.assertEqual((feed['releases'][0]['assets'][key]['url'],feed['releases'][0]['assets'][key]['size'],feed['releases'][0]['assets'][key]['sha256']), (BASE+name,size,digest))
        self.assertEqual(set(v1['releases'][0]['assets']),{'macos-arm64','macos-x86_64','windows-x64','linux-x64'})
        self.assertEqual(set(v2['releases'][0]['assets']),{'android'})
        self.assertEqual([(r['version'],r['build']) for r in v1['releases'] if 'android' in r['assets']],[('0.5.5',55)])
        self.assertIn('1.0.2',page)
        self.assertNotIn('v1.0.1',page)
        self.assertNotIn('1.0.2-ios-',readme.lower()+json.dumps(manifest).lower())
        self.assertNotIn('actions/upload-artifact@',(ROOT/'.github/workflows/ios-build.yml').read_text())

if __name__=='__main__': unittest.main()
