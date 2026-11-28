import fs from 'node:fs';import assert from 'node:assert/strict';import crypto from 'node:crypto';import * as asar from '@electron/asar';import * as PE from 'pe-library';import * as RE from 'resedit';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');const report={};
function sourceFiles(dir='app',prefix=''){
  return fs.readdirSync(dir,{withFileTypes:true}).flatMap(entry=>{
    const relative=prefix+entry.name,absolute=dir+'/'+entry.name;
    return entry.isDirectory()?sourceFiles(absolute,relative+'/'):[relative];
  }).sort();
}
// Electron Packager omits the app-root lockfile and native node-gyp object intermediates.
// Keep checking native .node binaries and all runtime JavaScript byte-for-byte.
const expected=sourceFiles().filter(file=>file!=='package-lock.json'&&!/^node_modules\/.+\/build\/.+\.o$/.test(file));
assert.ok(expected.includes('node_modules/ssh2/lib/client.js'),'SSH client must be installed in the packaged app');
for(const platform of ['win32','linux']){
  const root=`bundles-v107/diakitw-${platform}-x64`,archive=root+'/resources/app.asar';
  const list=asar.listPackage(archive).map(n=>n.replace(/^\//,'')).sort();
  const packedFiles=list.filter(n=>!('files' in asar.statFile(archive,n)));
  assert.deepEqual(packedFiles,expected,'ASAR must contain every authored file and runtime dependency');
  for(const file of expected){
    const packed=asar.extractFile(archive,file),source=fs.readFileSync('app/'+file);
    assert.equal(hash(packed),hash(source),file);
  }
  const pkg=JSON.parse(asar.extractFile(archive,'package.json'));
  assert.deepEqual(pkg,JSON.parse(fs.readFileSync('app/package.json')));
  assert.equal(pkg.main,'main.cjs');assert.equal(pkg.version,'1.0.7');assert.equal(pkg.name,'diakitw');
  assert.ok(fs.statSync(root+'/LICENSE').size>100);assert.ok(fs.statSync(root+'/LICENSES.chromium.html').size>1000);
  report[platform]={files:packedFiles,sourceParity:true,asarSHA256:hash(fs.readFileSync(archive)),licenses:true};
}
const b=fs.readFileSync('bundles-v107/diakitw-win32-x64/diakitw.exe');assert.equal(b.toString('ascii',0,2),'MZ');const off=b.readUInt32LE(60);assert.equal(b.readUInt16LE(off+4),0x8664);assert.equal(b.readUInt16LE(off+24),0x20b);
const exe=PE.NtExecutable.from(b);const res=PE.NtExecutableResource.from(exe);assert.ok(res.entries.some(e=>e.type===3&&hash(Buffer.from(e.bin))===hash(fs.readFileSync('app/icon.png'))));const v=RE.Resource.VersionInfo.fromEntries(res.entries)[0];assert.equal(v.fixedInfo.fileVersionMS,(1<<16));assert.equal(v.fixedInfo.fileVersionLS,(7<<16)|107);const versions=v.getAllLanguagesForStringValues().map(l=>v.getStringValues(l));assert.ok(versions.some(v=>v.ProductName==='diakitw'&&v.FileVersion==='1.0.7.107'&&v.ProductVersion==='1.0.7'));assert.equal(b.readUInt32LE(off+24+112+4*8+4),0,'Authenticode certificate size');assert.equal(report.win32.asarSHA256,report.linux.asarSHA256);assert.ok(asar.extractFile('bundles-v107/diakitw-linux-x64/resources/app.asar','index.html').toString().includes('diakitw 1.0.7'));report.win32={...report.win32,machine:'AMD64 PE32+',icon3Embedded:true,versionResources:versions,unsigned:true,exeSHA256:hash(b)};
const elf=fs.readFileSync('bundles-v107/diakitw-linux-x64/diakitw');assert.equal(elf.toString('hex',0,4),'7f454c46');assert.equal(elf[4],2);assert.equal(elf.readUInt16LE(18),62);assert.ok(fs.statSync('bundles-v107/diakitw-linux-x64/diakitw').mode&0o111);report.linux={...report.linux,machine:'ELF64 AMD64',executable:true,elfSHA256:hash(elf)};fs.writeFileSync('evidence/v107/bundles-verification.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
