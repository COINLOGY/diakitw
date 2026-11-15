"""Public 1.0.1 preview must expose only verified platform assets."""
import json
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
BASE='https://github.com/COINLOGY/diakitw/releases/download/v1.0.1/'
NAMES={'mac-silicon':'diakitw-1.0.1-macos-arm64.dmg','mac-intel':'diakitw-1.0.1-macos-x86_64.dmg','android':'diakitw-android-1.0.1.apk','windows':'diakitw-1.0.1-windows-x64.zip','linux':'diakitw-1.0.1-linux-x64.tar.gz'}

class Publication101(unittest.TestCase):
    def test_historical_101_feed_entries_retained(self):
        v1=json.loads((ROOT/'updates/v1.json').read_text())
        v2=json.loads((ROOT/'updates/v2.json').read_text())
        self.assertEqual(len([r for r in v1['releases'] if r['version']=='1.0.1' and r['channel']=='preview']),1)
        self.assertEqual(len([r for r in v2['releases'] if r['version']=='1.0.1' and r['channel']=='preview']),1)

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
