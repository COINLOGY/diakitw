const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const html=fs.readFileSync('app/index.html','utf8');
const css=fs.readFileSync('app/style.css','utf8');
const renderer=fs.readFileSync('app/renderer.js','utf8');
const workflow=()=>fs.readFileSync('../.github/workflows/desktop-106-candidate.yml','utf8');

test('106 metadata and visible version agree, with Windows PE fixed and string versions',()=>{
 const app=require('../app/package.json'),build=require('../package.json');
 assert.equal(app.version,'1.0.6');assert.equal(app.displayVersion,'1.0.6');assert.equal(app.build,106);assert.equal(build.version,'1.0.6');
 const lock=require('../package-lock.json');assert.equal(lock.version,'1.0.6');assert.equal(lock.packages[''].version,'1.0.6');
 assert.match(html,/diakitw 1\.0\.6/);
 const builder=fs.readFileSync('scripts/build-v106.mjs','utf8');
 const pe=fs.readFileSync('scripts/normalize-pe-v106.mjs','utf8');
 const verify=fs.readFileSync('scripts/verify-bundles-v106.mjs','utf8');
 for(const source of [builder,pe,verify])assert.match(source,/1\.0\.6/);
 assert.match(builder,/buildVersion:'1\.0\.6\.106'/);
 assert.match(pe,/setFileVersion\(1,0,5,106,0\)/);
 assert.match(verify,/FileVersion==='1\.0\.6\.106'/);
});

test('compact layout groups existing measured resources with network, then disk and honest explorer',()=>{
 assert.match(html,/<div class="monitor">[\s\S]*?id="metrics"[\s\S]*?class="network"[\s\S]*?<\/div><section id="disk-section"/);
 assert.match(html,/id="disk-map"[^>]*>[\s\S]*?недоступен/);
 for(const id of ['internet-test','diagnostics','terminal','tasks','cache','root','choose-folder','tools-menu','interface','rx-gauge','tx-gauge','history','disk-capacity','egress-flag'])assert.ok(html.includes(`id="${id}"`),id);
 assert.doesNotMatch(html,/Серверы|APFS|циклов|Крупнейшие 100|treemap/);
 assert.match(css,/\.monitor\s*\{[^}]*grid-template-columns:\s*minmax\(0,7fr\)\s+minmax\(0,5fr\)/);
 assert.match(css,/@media\s*\(max-width:.*?\)[\s\S]*?\.monitor\s*\{grid-template-columns:1fr\}/);
 assert.match(css,/#metrics\s*\{[^}]*grid-template-columns:repeat\(4,minmax\(0,1fr\)\)/);
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

test('106 candidate workflow binds exact source SHA, preserves archive modes and never publishes',()=>{
 const w=workflow();
 for(const s of ['feat/release-106-candidate','npm test','build-v106.mjs win32','build-v106.mjs linux','normalize-pe-v106.mjs','verify-bundles-v106.mjs','verify-upstream-v106.py','archive-v106.py','verify-archives-v106.py','source-commit.txt','GITHUB_SHA','diakitw-1.0.6-windows-x64.zip','diakitw-1.0.6-linux-x64.tar.gz','release-manifest-1.0.6.json'])assert.ok(w.includes(s),s);
 assert.match(w,/if: github\.ref == 'refs\/heads\/feat\/release-106-candidate'/);
 assert.doesNotMatch(w,/gh release |overwrite: true|git push|pages|feed\.json/);
 const archive=fs.readFileSync('scripts/archive-v106.py','utf8');
 assert.match(archive,/README-CANDIDATE\.txt/);assert.match(archive,/EXE неподписан/);assert.match(archive,/tarfile\.open/);
 const verification=fs.readFileSync('scripts/verify-archives-v106.py','utf8');assert.match(verification,/m\.mode&0o777/);
});
