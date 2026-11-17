const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const html=fs.readFileSync('app/index.html','utf8');
const renderer=fs.readFileSync('app/renderer.js','utf8');
const css=fs.readFileSync('app/style.css','utf8');

test('resource, network and disk sections are distinct and ordered; file analysis is honestly unavailable',()=>{
 const order=['id="metrics"','class="network"','id="disk-section"','id="disk-map"'];
 let previous=-1;for(const marker of order){const next=html.indexOf(marker);assert.ok(next>previous,marker);previous=next;}
 assert.match(html,/id="disk-capacity"/);
 assert.match(html,/id="disk-used"/);
 assert.match(html,/id="disk-free"/);
 assert.match(html,/id="disk-map"[^>]*>[\s\S]*?недоступен/);
 assert.match(html,/id="rx-gauge"[\s\S]*id="tx-gauge"[\s\S]*id="history"/);
 assert.doesNotMatch(renderer,/\['cpu','CPU'\],[\s\S]*\['disk','Диск'\]/);
 assert.match(css,/#disk-section\{/);
});

test('capacity overview uses measured bytes and distinguishes unknown from zero',()=>{
 const start=renderer.indexOf('function updateDisk('),end=renderer.indexOf('function drawHistory(');
 assert.ok(start>=0&&end>start,'disk renderer exists');
 const elements=Object.fromEntries(['disk-used','disk-free','disk-capacity','disk-root'].map(id=>[id,{textContent:'',style:{},attributes:{},setAttribute(k,v){this.attributes[k]=v},removeAttribute(k){delete this.attributes[k]}}]));
 const sandbox={$:id=>elements[id],valid:n=>typeof n==='number'&&Number.isFinite(n)&&n>=0,amount:n=>Number.isFinite(n)&&n>=0?(n/1073741824).toFixed(1):'Н/Д',Math};
 vm.createContext(sandbox);vm.runInContext(renderer.slice(start,end)+';this.updateDisk=updateDisk',sandbox);
 sandbox.updateDisk({used:200*2**30,total:500*2**30},'/');
 assert.match(elements['disk-used'].textContent,/200\.0 GiB/);
 assert.match(elements['disk-free'].textContent,/300\.0 GiB/);
 assert.equal(elements['disk-capacity'].style.width,'40%');
 assert.equal(elements['disk-capacity'].attributes['aria-valuenow'],'40');
 sandbox.updateDisk({used:0,total:500*2**30},'/');
 assert.equal(elements['disk-capacity'].style.width,'0%');
 assert.match(elements['disk-used'].textContent,/0\.0 GiB/);
 sandbox.updateDisk({used:null,total:null},'/');
 assert.equal(elements['disk-capacity'].style.width,'0%');
 assert.equal(elements['disk-capacity'].attributes['aria-valuenow'],undefined);
 assert.match(elements['disk-used'].textContent,/Н\/Д/);
 assert.match(elements['disk-free'].textContent,/Н\/Д/);
 sandbox.updateDisk({used:600,total:500},'/');
 assert.equal(elements['disk-capacity'].attributes['aria-valuenow'],undefined);
});
