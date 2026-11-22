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
