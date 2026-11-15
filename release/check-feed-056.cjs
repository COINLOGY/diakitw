const fs = require('node:fs');
const assert = require('node:assert/strict');
const {select} = require('../diakitw-desktop/app/updates.cjs');
const feed = fs.readFileSync(process.argv[2] || 'updates/v1.json', 'utf8');
const manifest = JSON.parse(fs.readFileSync('manifest.json', 'utf8'));
const byId = Object.fromEntries(manifest.platforms.map(p => [p.id, p]));
for (const [platform, id] of Object.entries({'macos-arm64':'mac-silicon','macos-x86_64':'mac-intel','windows-x64':'windows','linux-x64':'linux'})) {
  const p = byId[id];
  const preview = select(feed, platform, 'preview', '0.5.5', 55);
  assert.equal(preview?.version, '1.0.1');
  assert.equal(preview?.build, 101);
  assert.equal(preview?.asset.url, p.url);
  assert.equal(preview?.asset.size, p.size_bytes);
  assert.equal(preview?.asset.sha256, p.sha256);
  assert.equal(select(feed, platform, 'preview', '1.0.1', 101), null);
  const stable = select(feed, platform, 'stable', '0.5.4', 54);
  assert.equal(stable?.version, platform.startsWith('macos-') ? '0.5.6' : '0.5.5');
  if (platform.startsWith('macos-')) {
    assert.equal(select(feed, platform, 'stable', '0.5.6', 56), null);
  } else {
    assert.equal(select(feed, platform, 'stable', '0.5.5', 55), null);
  }
}
assert.equal(select(feed, 'android', 'preview', '0.5.5', 55), null);
assert.equal(select(feed, 'android', 'stable', '0.5.5', 55), null);
assert.equal(select(feed, 'android', 'stable', '0.5.4', 54)?.version, '0.5.5');
console.log('PASS: v1 preview 1.0.1 desktop only; stable and legacy Android remain isolated');
