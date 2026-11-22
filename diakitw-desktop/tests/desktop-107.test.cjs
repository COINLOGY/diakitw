const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const html=fs.readFileSync('app/index.html','utf8');
const css=fs.readFileSync('app/style.css','utf8');
const renderer=fs.readFileSync('app/renderer.js','utf8');
const workflow=()=>fs.readFileSync('../.github/workflows/desktop-107-candidate.yml','utf8');

test('107 metadata and visible version agree, with Windows PE fixed and string versions',()=>{
 const app=require('../app/package.json'),build=require('../package.json');
 assert.equal(app.version,'1.0.7');assert.equal(app.displayVersion,'1.0.7');assert.equal(app.build,107);assert.equal(build.version,'1.0.7');
 const lock=require('../package-lock.json');assert.equal(lock.version,'1.0.7');assert.equal(lock.packages[''].version,'1.0.7');
 assert.match(html,/diakitw 1\.0\.7/);
 const builder=fs.readFileSync('scripts/build-v107.mjs','utf8');
 const pe=fs.readFileSync('scripts/normalize-pe-v107.mjs','utf8');
 const verify=fs.readFileSync('scripts/verify-bundles-v107.mjs','utf8');
 for(const source of [builder,pe,verify])assert.match(source,/1\.0\.7/);
 assert.match(builder,/buildVersion:'1\.0\.7\.107'/);
 assert.match(pe,/setFileVersion\(1,0,7,107,0\)/);
 assert.match(verify,/FileVersion==='1\.0\.7\.107'/);
});

test('compact layout groups existing measured resources with network, then disk and honest explorer',()=>{
 assert.match(html,/<div class="monitor">[\s\S]*?id="metrics"[\s\S]*?class="network"[\s\S]*?<\/div><section id="disk-section"/);
 assert.match(html,/id="disk-map"[^>]*>[\s\S]*?недоступен/);
 for(const id of ['internet-test','diagnostics','terminal','tasks','cache','root','choose-folder','tools-menu','interface','rx-gauge','tx-gauge','history','disk-capacity','egress-flag'])assert.ok(html.includes(`id="${id}"`),id);
 assert.doesNotMatch(html.split('<div id="overview-view">')[1].split('<section id="servers-view"')[0],/APFS|циклов|Крупнейшие 100|treemap|Батарея/);
 assert.match(css,/\.monitor\s*\{[^}]*grid-template-columns:\s*minmax\(0,7fr\)\s+minmax\(0,5fr\)/);
 assert.match(css,/@media\s*\(max-width:.*?\)[\s\S]*?\.monitor\s*\{grid-template-columns:1fr\}/);
 assert.match(css,/#metrics\s*\{[^}]*grid-template-columns:repeat\(3,minmax\(0,1fr\)\)/);
 assert.match(css,/\.toolbar\s*\{[^}]*flex-wrap:wrap/);
 assert.match(renderer,/const flag=countryFlag\(s\)/);
});

test('compact gauges reserve enough canvas height to keep measured dial arcs visible',()=>{
 const vm=require('node:vm');
 const source=renderer.slice(renderer.indexOf('function gauge('),renderer.indexOf('function updateCard('));
 const arcs=[];const ctx=new Proxy({measureText:t=>({width:String(t).length*7}),arc:(...args)=>arcs.push(args)},{get:(o,k)=>k in o?o[k]:()=>{}});
 const sandbox={context:()=>[ctx,110,86,12],valid:n=>typeof n==='number'&&Number.isFinite(n)&&n>=0,band:()=> 'blue',colors:{green:'green',blue:'blue',red:'red',neutral:'gray'},Math};
 vm.createContext(sandbox);vm.runInContext(source+';this.draw=gauge',sandbox);
 sandbox.draw({dataset:{}},50,false);assert.ok(arcs.some(a=>a[2]>20),'compact resource gauge must draw arc');
 arcs.length=0;sandbox.draw({dataset:{}},50,false,{max:8,unit:'MiB/s',color:'green'});assert.ok(arcs.some(a=>a[2]>20),'compact network gauge must draw arc');
 assert.match(css,/\.metric \.gauge\{[^}]*height:(8[0-9]|9[0-9])px/);
 assert.match(css,/\.rate-gauge\{[^}]*height:(8[0-9]|9[0-9])px/);
 assert.match(css,/@media\(max-width:35rem\)\{[^}]*\.network \.speeds\{grid-template-columns:1fr\}/);
});

test('bundle verifier hashes nested runtime dependencies, not directories as files',()=>{
 const source=fs.readFileSync('scripts/verify-bundles-v107.mjs','utf8');
 assert.match(source,/sourceFiles\(absolute,relative\+'\/'\)/);
 assert.match(source,/node_modules\/ssh2\/lib\/client\.js/);
 assert.match(source,/asar\.statFile\(archive,n\)/);
 assert.match(source,/asar\.extractFile\(archive,file\)/);
 assert.doesNotMatch(source,/assert\.deepEqual\(list\.map\(n=>n\.replace/);
});

test('107 candidate workflow binds exact source SHA, preserves archive modes and never publishes',()=>{
 const w=workflow();
 for(const s of ['feat/release-107-candidate','npm test','build-v107.mjs win32','build-v107.mjs linux','normalize-pe-v107.mjs','verify-bundles-v107.mjs','verify-upstream-v107.py','archive-v107.py','verify-archives-v107.py','source-commit.txt','GITHUB_SHA','diakitw-1.0.7-windows-x64.zip','diakitw-1.0.7-linux-x64.tar.gz','release-manifest-1.0.7.json'])assert.ok(w.includes(s),s);
 assert.match(w,/if: github\.ref == 'refs\/heads\/feat\/release-107-candidate'/);
 assert.doesNotMatch(w,/gh release |overwrite: true|git push|pages|feed\.json/);
 const archive=fs.readFileSync('scripts/archive-v107.py','utf8');
 assert.match(archive,/README-CANDIDATE\.txt/);assert.match(archive,/EXE неподписан/);assert.match(archive,/tarfile\.open/);
 const verification=fs.readFileSync('scripts/verify-archives-v107.py','utf8');assert.match(verification,/m\.mode&0o777/);
});
