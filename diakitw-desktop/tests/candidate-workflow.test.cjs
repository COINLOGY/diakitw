const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('arrow candidate CI packages both desktop platforms without publishing', () => {
  const workflow = fs.readFileSync(path.resolve(__dirname, '../../.github/workflows/network-arrows-candidate.yml'), 'utf8');
  for (const token of [
    'fix/network-arrows-after-units', 'npm ci', 'npm test',
    'node scripts/build-v055a.mjs win32', 'node scripts/build-v055a.mjs linux',
    'node scripts/verify-bundles-v055a.mjs',
    'python3 scripts/verify-upstream-v055a.py',
    'diakitw-network-arrows-windows-x64-UNRELEASED',
    'diakitw-network-arrows-linux-x64-UNRELEASED',
    "Path('bundles-v055a/diakitw-win32-x64')", '-C bundles-v055a diakitw-linux-x64',
  ]) assert.ok(workflow.includes(token), `missing candidate gate ${token}`);
  assert.ok(!workflow.includes('gh release '), 'candidate CI must not publish a release');
});

test('candidate CI only runs on the intended branch and identifies exact commit', () => {
  const workflow = fs.readFileSync(path.resolve(__dirname, '../../.github/workflows/network-arrows-candidate.yml'), 'utf8');
  assert.match(workflow, /if: github\.ref == 'refs\/heads\/fix\/network-arrows-after-units'/);
  assert.match(workflow, /diakitw-network-arrows-windows-x64-UNRELEASED-\$\{\{ github\.sha \}\}/);
  assert.match(workflow, /diakitw-network-arrows-linux-x64-UNRELEASED-\$\{\{ github\.sha \}\}/);
  assert.match(workflow, /source-commit\.txt/);
});

test('candidate archives preserve Linux executable permissions', () => {
  const workflow = fs.readFileSync(path.resolve(__dirname, '../../.github/workflows/network-arrows-candidate.yml'), 'utf8');
  assert.ok(workflow.includes('tar -czf candidate/diakitw-network-arrows-linux-x64-UNRELEASED.tar.gz -C bundles-v055a'));
  assert.ok(workflow.includes('zipfile.ZipFile'));
  assert.ok(workflow.includes('candidate/diakitw-network-arrows-windows-x64-UNRELEASED.zip'));
});
