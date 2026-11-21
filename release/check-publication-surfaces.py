"""Validate public-facing release surfaces against the manifest for the current version."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
m = json.loads((ROOT / 'manifest.json').read_text(encoding='utf-8'))
v1 = json.loads((ROOT / 'updates/v1.json').read_text(encoding='utf-8'))
v2 = json.loads((ROOT / 'updates/v2.json').read_text(encoding='utf-8'))
readme = (ROOT / 'README.md').read_text(encoding='utf-8')
page = (ROOT / 'index.html').read_text(encoding='utf-8')
by_id = {p['id']: p for p in m['platforms']}
cur = by_id['mac-silicon']
CV = cur['version']
CB = cur['build']
assert m['prerelease'] is True and CV in m['release']
assert set(by_id) == {'mac-silicon', 'mac-intel', 'android', 'windows', 'linux'}
assert CV in readme and CV in page
assert 'iOS' in readme and 'iOS' in page and f'-{CV}-ios-' not in readme + page
base = f'https://github.com/COINLOGY/diakitw/releases/download/v{CV}/'
for p in by_id.values():
    assert (p['version'], p['displayVersion'], p['build']) == (CV, CV, CB)
    assert p['url'] == base + p['filename'] and len(p['sha256']) == 64 and p['size_bytes'] > 0
    assert any(f'[{p["filename"]}]({p["url"]})' in line and p['sha256'] in line for line in readme.splitlines()), p['filename']
preview1 = [r for r in v1['releases'] if r['version'] == CV and r['channel'] == 'preview']
preview2 = [r for r in v2['releases'] if r['version'] == CV and r['channel'] == 'preview']
assert len(preview1) == len(preview2) == 1
mapping = {'macos-arm64': 'mac-silicon', 'macos-x86_64': 'mac-intel', 'windows-x64': 'windows', 'linux-x64': 'linux'}
assert set(preview1[0]['assets']) == set(mapping) and set(preview2[0]['assets']) == {'android'}
for platform, pid in mapping.items():
    p = by_id[pid]
    a = preview1[0]['assets'][platform]
    expected_url = p['url'].replace('-macos-unsigned-', '-macos-')
    assert (a['url'], a['size'], a['sha256']) == (expected_url, p['size_bytes'], p['sha256']), platform
p = by_id['android']
a = preview2[0]['assets']['android']
assert (a['url'], a['size'], a['sha256']) == (p['url'], p['size_bytes'], p['sha256'])
assert [(r['version'], r['build']) for r in v1['releases'] if 'android' in r['assets']] == [('0.5.5', 55)]
assert 'm.release' in (ROOT / 'site.js').read_text(encoding='utf-8')
print(f'PASS: {CV}/{CB} source surfaces and feeds are consistent; no iOS asset in v1')
