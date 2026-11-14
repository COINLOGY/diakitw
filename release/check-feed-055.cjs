const fs=require('node:fs'),assert=require('node:assert/strict');
const {select}=require(require('node:path').resolve(process.argv[2]));
const text=fs.readFileSync('release/fixtures/v1-0.5.5.json','utf8');
for(const p of ['windows-x64','linux-x64','android','macos-arm64','macos-x86_64']) {
 const offer=select(text,p,'stable','0.5.4',54); assert.equal(offer.version,'0.5.5');assert.equal(offer.build,55);
 assert.match(offer.notes,/uninstall/);assert.match(offer.notes,/данные/);
 for(const [v,b] of [['0.5.5',55],['0.5.6',56]]) assert.equal(select(text,p,'stable',v,b),null);
 assert.equal(select(text,p,'preview','0.5.4',54),null);
}
console.log('PASS Desktop exact final five-platform feed: old/current/newer/channel/migration notes');
