const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {spawnSync}=require('node:child_process');

test('1.0.7 verifier accepts real packaged Windows and Linux ASAR parity',{skip:!fs.existsSync('bundles-v107/diakitw-linux-x64/resources/app.asar')},()=>{
  const run=spawnSync(process.execPath,['scripts/verify-bundles-v107.mjs'],{encoding:'utf8'});
  assert.equal(run.status,0,run.stderr);
  const report=JSON.parse(fs.readFileSync('evidence/v107/bundles-verification.json'));
  for(const platform of ['win32','linux']){
    assert.equal(report[platform].sourceParity,true);
    assert.ok(report[platform].files.includes('node_modules/ssh2/lib/client.js'));
    assert.ok(!report[platform].files.includes('package-lock.json'));
  }
});

test('node-gyp object intermediates are not expected in the distributable ASAR',{skip:!fs.existsSync('bundles-v107/diakitw-linux-x64/resources/app.asar')},()=>{
 const path=require('node:path');const object=path.join('app','node_modules','ssh2','build','obj.target','parity-object-test.o');
 fs.mkdirSync(path.dirname(object),{recursive:true});fs.writeFileSync(object,'compiler intermediate; not runtime');
 try{
  const run=spawnSync(process.execPath,['scripts/verify-bundles-v107.mjs'],{encoding:'utf8'});
  assert.equal(run.status,0,run.stderr);
  const report=JSON.parse(fs.readFileSync('evidence/v107/bundles-verification.json'));
  for(const platform of ['win32','linux'])assert.ok(!report[platform].files.includes('node_modules/ssh2/build/obj.target/parity-object-test.o'));
 }finally{fs.unlinkSync(object);}
});

test('desktop CI omits optional host-native SSH accelerators for cross-platform bundles',()=>{
  const workflow=fs.readFileSync('../.github/workflows/desktop-107-candidate.yml','utf8');
  assert.match(workflow,/npm ci --prefix app --omit=dev --omit=optional --ignore-scripts --no-audit --no-fund/);
  const ssh=require('../app/node_modules/ssh2');
  assert.equal(typeof ssh.Client,'function','SSH uses its portable implementation without optional native accelerators');
});

test('required SSH native binding is absent from installed runtime dependencies',()=>{
  const path=require('node:path');const found=[];
  const scan=(dir)=>{for(const entry of fs.readdirSync(dir,{withFileTypes:true})){
    const file=path.join(dir,entry.name);if(entry.isDirectory())scan(file);else if(entry.name.endsWith('.node'))found.push(file);
  }};
  scan('app/node_modules');
  assert.deepEqual(found,[],'cross-target portable bundles cannot contain host-native .node bindings');
});
