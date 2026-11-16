"""Validate 1.0.3 public-facing source surfaces against verified assets."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
m=json.loads((ROOT/'manifest.json').read_text())
v1=json.loads((ROOT/'updates/v1.json').read_text())
v2=json.loads((ROOT/'updates/v2.json').read_text())
readme=(ROOT/'README.md').read_text()
page=(ROOT/'index.html').read_text()
by_id={p['id']:p for p in m['platforms']}
assert m['prerelease'] is True and '1.0.3' in m['release']
assert set(by_id)=={'mac-silicon','mac-intel','android','windows','linux'}
assert '1.0.3' in readme and '1.0.3' in page
assert 'iOS' in readme and 'iOS' in page and '1.0.3-ios-' not in readme+page
base='https://github.com/COINLOGY/diakitw/releases/download/v1.0.3/'
for p in by_id.values():
 assert (p['version'],p['displayVersion'],p['build'])==('1.0.3','1.0.3',103)
 assert p['url']==base+p['filename'] and len(p['sha256'])==64 and p['size_bytes']>0
 assert any(f'[{p["filename"]}]({p["url"]})' in line and p['sha256'] in line for line in readme.splitlines())
preview1=[r for r in v1['releases'] if r['version']=='1.0.3' and r['channel']=='preview']
preview2=[r for r in v2['releases'] if r['version']=='1.0.3' and r['channel']=='preview']
assert len(preview1)==len(preview2)==1
mapping={'macos-arm64':'mac-silicon','macos-x86_64':'mac-intel','windows-x64':'windows','linux-x64':'linux'}
assert set(preview1[0]['assets'])==set(mapping) and set(preview2[0]['assets'])=={'android'}
for platform,pid in mapping.items():
 p=by_id[pid];a=preview1[0]['assets'][platform]
 assert (a['url'],a['size'],a['sha256'])==(p['url'],p['size_bytes'],p['sha256'])
p=by_id['android'];a=preview2[0]['assets']['android']
assert (a['url'],a['size'],a['sha256'])==(p['url'],p['size_bytes'],p['sha256'])
assert [(r['version'],r['build']) for r in v1['releases'] if 'android' in r['assets']]==[('0.5.5',55)]
assert 'm.release' in (ROOT/'site.js').read_text()
print('PASS: 1.0.3 source surfaces/feeds consistent; no new-key Android in v1; no iOS asset')
