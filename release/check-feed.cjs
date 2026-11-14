const fs=require('node:fs'), assert=require('node:assert/strict');
const {select}=require('../diakitw-desktop/app/updates.cjs');
const text=fs.readFileSync(process.argv[2]||'release/fixtures/v1-0.5.4.json','utf8');
for(const platform of ['windows-x64','linux-x64','android','macos-arm64','macos-x86_64']) {
 assert.equal(select(text,platform,'preview','0.5.3',53).version,'0.5.4');
 assert.equal(select(text,platform,'preview','0.5.4',54),null);
 assert.equal(select(text,platform,'preview','0.5.5',55),null);
 assert.equal(select(text,platform,'stable','0.5.3',53),null);
}
console.log('Desktop actual shared manifest PASS: five platforms; older/current/newer/stable');
