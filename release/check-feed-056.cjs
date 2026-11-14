const fs = require('node:fs');
const assert = require('node:assert/strict');
const {select} = require('../diakitw-desktop/app/updates.cjs');
const feed = fs.readFileSync(process.argv[2] || 'updates/v1.json', 'utf8');
const expected = {
  'macos-arm64': [1593991, '6dee475414c194d69e3635f22445c4cb027ca8868a7c3e99f01d6b20a6dbc1ba'],
  'macos-x86_64': [1723342, 'c72df7c6de13bc0205e65b2ab8389990e67fffbc967b34a10799e4dd878c0a74']
};
for (const platform of ['macos-arm64', 'macos-x86_64']) {
  for (const channel of ['stable', 'preview']) {
    const offer = select(feed, platform, channel, '0.5.5', 55);
    assert.equal(offer?.version, '0.5.6');
    assert.equal(offer?.build, 56);
    assert.equal(offer?.asset.size, expected[platform][0]);
    assert.equal(offer?.asset.sha256, expected[platform][1]);
    assert.equal(select(feed, platform, channel, '0.5.6', 56), null);
  }
}
for (const platform of ['windows-x64', 'linux-x64', 'android']) {
  assert.equal(select(feed, platform, 'stable', '0.5.5', 55), null);
  assert.equal(select(feed, platform, 'stable', '0.5.4', 54)?.version, '0.5.5');
}
console.log('PASS: desktop 0.5.6 feed, both channels; other platforms unchanged');
