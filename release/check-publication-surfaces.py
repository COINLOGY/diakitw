"""Release pages must agree with the shipped per-platform assets."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / 'manifest.json').read_text())
feed = json.loads((ROOT / 'updates/v1.json').read_text())
readme = (ROOT / 'README.md').read_text()
page = (ROOT / 'index.html').read_text()
by_id = {p['id']: p for p in manifest['platforms']}
def checksum_matches(text, p):
    link = f'[{p["filename"]}]({p["url"]})'
    return any(link in line and f'SHA-256 `{p["sha256"]}`' in line for line in text.splitlines())

assert len(by_id) == len(manifest['platforms']) == 5
assert 'macOS 0.5.6' in manifest['release'] and '0.5.5a' in manifest['release']
assert 'macOS 0.5.6' in readme and '0.5.5a' in readme
assert 'macOS 0.5.6' in page and '0.5.5a' in page
assert 'diakitw-0.5.5-macos-' not in readme + page

for pid, platform in [('mac-silicon', 'macos-arm64'), ('mac-intel', 'macos-x86_64')]:
    asset = feed['releases'][0]['assets'][platform]
    p = by_id[pid]
    assert (p['version'], p['displayVersion'], p['build']) == ('0.5.6', '0.5.6', 56)
    assert (p['url'], p['size_bytes'], p['sha256']) == (asset['url'], asset['size'], asset['sha256'])
    assert p['filename'] == asset['url'].rsplit('/', 1)[1]
    assert f'[{p["filename"]}]({p["url"]})' in readme
    # The visible checksum must match the downloadable bytes, not just the URL.
    assert checksum_matches(readme, p)
    assert not checksum_matches(readme.replace(p['sha256'], '0' * 64, 1), p)
    assert p['url'].startswith('https://github.com/COINLOGY/diakitw/releases/download/v0.5.6/')

for pid in ['android', 'windows', 'linux']:
    p = by_id[pid]
    assert (p['version'], p['displayVersion'], p['build']) == ('0.5.5', '0.5.5a', 55)
    assert f'[{p["filename"]}]({p["url"]})' in readme
    assert '/releases/download/v0.5.5/' in p['url']

assert 'https://github.com/COINLOGY/diakitw/releases/tag/v0.5.6' in readme
assert 'https://github.com/COINLOGY/diakitw/releases/tag/v0.5.5' in readme
assert 'https://github.com/COINLOGY/diakitw/releases/tag/v0.5.6' in page
assert 'https://github.com/COINLOGY/diakitw/releases/tag/v0.5.5' in page
assert 'macOS 0.5.6' in (ROOT / 'site.js').read_text() or 'm.release' in (ROOT / 'site.js').read_text()
print('PASS: README, site and manifest agree with platform-specific release feed')
