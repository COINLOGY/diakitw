"""Public 1.0.1 preview must expose only verified platform assets."""
import json
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
BASE='https://github.com/COINLOGY/diakitw/releases/download/v1.0.1/'
NAMES={'mac-silicon':'diakitw-1.0.1-macos-arm64.dmg','mac-intel':'diakitw-1.0.1-macos-x86_64.dmg','android':'diakitw-android-1.0.1.apk','windows':'diakitw-1.0.1-windows-x64.zip','linux':'diakitw-1.0.1-linux-x64.tar.gz'}

class Publication101(unittest.TestCase):
    def test_manifest_readme_and_page_reference_verified_assets(self):
        manifest=json.loads((ROOT/'manifest.json').read_text())
        readme=(ROOT/'README.md').read_text()
        page=(ROOT/'index.html').read_text()
        self.assertTrue(manifest['prerelease'])
        self.assertIn('1.0.1',manifest['release'])
        self.assertEqual([p['id'] for p in manifest['platforms']],list(NAMES))
        for p in manifest['platforms']:
            self.assertEqual((p['version'],p['displayVersion'],p['build']),('1.0.1','1.0.1',101))
            self.assertEqual((p['filename'],p['url']),(NAMES[p['id']],BASE+NAMES[p['id']]))
            self.assertGreater(p['size_bytes'],0)
            self.assertRegex(p['sha256'],r'^[0-9a-f]{64}$')
            self.assertTrue(any(f'[{p["filename"]}]({p["url"]})' in line and p['sha256'] in line for line in readme.splitlines()))
        self.assertIn('1.0.1',page)
        self.assertNotIn('1.0.1-ios-',readme+page)
        self.assertNotIn('1.0.1-ios-',json.dumps(manifest))
        ios_workflow=(ROOT/'.github/workflows/ios-build.yml').read_text()
        self.assertIn('workflow_dispatch:',ios_workflow)
        self.assertNotIn('actions/upload-artifact@',ios_workflow)
        self.assertIn('d9298271dcb4e32856abdc2111b35ae43b7770b1c9fbfefa66100e899a58abc8',readme)

    def test_preview_feeds_keep_legacy_android_isolated(self):
        v1=json.loads((ROOT/'updates/v1.json').read_text())
        v2=json.loads((ROOT/'updates/v2.json').read_text())
        preview1=[r for r in v1['releases'] if r['version']=='1.0.1' and r['channel']=='preview']
        preview2=[r for r in v2['releases'] if r['version']=='1.0.1' and r['channel']=='preview']
        self.assertEqual(len(preview1),1)
        self.assertEqual(set(preview1[0]['assets']),{'macos-arm64','macos-x86_64','windows-x64','linux-x64'})
        self.assertEqual(len(preview2),1)
        self.assertEqual(set(preview2[0]['assets']),{'android'})
        for r in preview1+preview2:
            self.assertEqual(r['build'],101)
            for asset in r['assets'].values():self.assertTrue(asset['url'].startswith(BASE))
        self.assertEqual([(r['version'],r['build']) for r in v1['releases'] if 'android' in r['assets']],[('0.5.5',55)])

if __name__=='__main__':unittest.main()
