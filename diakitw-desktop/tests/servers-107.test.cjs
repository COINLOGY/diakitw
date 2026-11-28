const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const os=require('node:os');
const crypto=require('node:crypto');
const {EventEmitter}=require('node:events');
const {Readable}=require('node:stream');
const {ProfileStore,parseSample,ServerMonitor,validateProfile,saveServerSession}=require('../app/servers.cjs');

test('profiles persist without passwords and reject invalid or unverified targets',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'diakitw-servers-'));
 try{
  const store=new ProfileStore(path.join(dir,'profiles.json'));
  assert.throws(()=>validateProfile({name:'x',host:'example.org',port:22,user:'alice',auth:'password'}),/отпечаток/i);
  assert.throws(()=>validateProfile({name:'x',host:'bad;cat',port:22,user:'alice',auth:'password',fingerprint:'SHA256:'+('A'.repeat(43))}),/адрес/i);
  const p=store.save({name:'Test',host:'example.org',port:2222,user:'alice',auth:'password',fingerprint:'SHA256:'+('A'.repeat(43)),password:'secret'});
  assert.equal(store.list().length,1);assert.equal(store.list()[0].password,undefined);
  assert.equal(fs.statSync(path.join(dir,'profiles.json')).mode&0o777,0o600);
  assert.doesNotMatch(fs.readFileSync(path.join(dir,'profiles.json'),'utf8'),/secret/);
  assert.equal(new ProfileStore(path.join(dir,'profiles.json')).list()[0].id,p.id);
  store.remove(p.id);assert.equal(store.list().length,0);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});

test('Linux sample parser reports measured CPU, RAM, SWAP and root disk without inventing missing readings',()=>{
 const raw='STAT\ncpu  100 0 20 380 0 0 0 0 0 0\nMEM\nMemTotal:       1000 kB\nMemAvailable:    400 kB\nSwapTotal:       200 kB\nSwapFree:        150 kB\nDISK\nFilesystem 1B-blocks Used Available Use% Mounted on\n/dev/root 1000000 250000 750000 25% /\n';
 const first=parseSample(raw,null);assert.equal(first.cpu,null);assert.deepEqual(first.ram,{used:614400,total:1024000});assert.deepEqual(first.swap,{used:51200,total:204800});assert.deepEqual(first.disk,{used:250000,total:1000000});
 const second=parseSample(raw.replace('100 0 20 380','130 0 20 450'),first.counters);assert.ok(Math.abs(second.cpu-30)<0.001);
 const absent=parseSample('STAT\nMEM\nDISK\n',null);assert.equal(absent.cpu,null);assert.equal(absent.disk.used,null);assert.equal(absent.ram.total,null);
});

test('SSH connection requires exact independently supplied host fingerprint and never executes writes',async()=>{
 const key=Buffer.from('test-host-key');const fingerprint='SHA256:'+crypto.createHash('sha256').update(key).digest('base64').replace(/=+$/,'');
 const calls=[];class FakeClient extends EventEmitter{
  connect(config){calls.push(config);queueMicrotask(()=>config.hostVerifier(key)?this.emit('ready'):this.emit('error',Error('host verification failed')));return this;}
  exec(command,cb){calls.push(command);const stream=new Readable({read(){}});stream.stderr=new Readable({read(){this.push(null)}});cb(null,stream);stream.push('STAT\ncpu  100 0 0 900 0 0 0 0\nMEM\nMemTotal: 1000 kB\nMemAvailable: 500 kB\nDISK\n');stream.push(null);stream.once('end',()=>stream.emit('close',0));}
  end(){}
 }
 const monitor=new ServerMonitor({client:FakeClient});const p={id:'1',name:'x',host:'example.org',port:22,user:'alice',auth:'password',fingerprint};
 const result=await monitor.sample(p,'transient');assert.equal(result.ram.used,512000);assert.equal(calls[0].password,'transient');assert.equal(calls[0].hostVerifier(key),true);assert.equal(calls[0].hostVerifier(Buffer.from('wrong')),false);assert.match(calls[1],/^LC_ALL=C /);assert.doesNotMatch(calls[1],/sudo|systemctl|\brm\b/);
 await assert.rejects(()=>monitor.sample({...p,fingerprint:'SHA256:'+('A'.repeat(43))},'transient'),/отпечаток/i);
});


test('endpoint edits discard the previous session password and require fresh credentials',async()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'diakitw-session-'));
 try{
  const store=new ProfileStore(path.join(dir,'profiles.json')),passwords=new Map();
  const base={name:'a',host:'example.org',port:22,user:'alice',auth:'password',fingerprint:'SHA256:'+'A'.repeat(43)};
  const original=saveServerSession(store,passwords,{...base,password:'old-secret'});
  assert.equal(passwords.get(original.id),'old-secret');
  saveServerSession(store,passwords,{...original,name:'new label'});
  assert.equal(passwords.get(original.id),'old-secret','renaming should retain session credentials');
  for(const changed of [{host:'other.org'},{port:2222},{user:'bob'},{fingerprint:'SHA256:'+'B'.repeat(43)}]){
   const current=store.list()[0];
   saveServerSession(store,passwords,{...current,...changed});
   assert.equal(passwords.has(original.id),false,JSON.stringify(changed));
   await assert.rejects(()=>new ServerMonitor().sample(store.list()[0],passwords.get(original.id)),/пароль/i);
   saveServerSession(store,passwords,{...store.list()[0],password:'fresh-secret'});
   assert.equal(passwords.get(original.id),'fresh-secret');
  }
  saveServerSession(store,passwords,{...store.list()[0],auth:'key',keyPath:'/test/key'});
  assert.equal(passwords.has(original.id),false);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});

test('SSH key read is asynchronous and bounded before any connection',async()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'diakitw-key-'));
 const keyPath=path.join(dir,'oversized.key');fs.writeFileSync(keyPath,Buffer.alloc(1024*1024));
 const originalRead=fs.readFileSync,originalOpen=fs.promises.open;let maximum=0,connections=0;
 fs.readFileSync=function(file,...args){if(file===keyPath)throw Error('synchronous key read');return originalRead.call(this,file,...args);};
 fs.promises.open=async function(file,...args){const handle=await originalOpen.call(this,file,...args);if(file===keyPath){const read=handle.read.bind(handle);handle.read=(buffer,...rest)=>{maximum=Math.max(maximum,buffer.length);return read(buffer,...rest);};}return handle;};
 try{
  const monitor=new ServerMonitor({client:class{constructor(){connections++;}}});
  const pending=monitor.sample({id:'key',auth:'key',keyPath},undefined);
  assert.ok(pending instanceof Promise);
  await assert.rejects(pending,/Ключ слишком большой/);
  assert.equal(maximum,0,'oversized key rejected by file metadata before read');
  assert.equal(connections,0);
 }finally{fs.readFileSync=originalRead;fs.promises.open=originalOpen;fs.rmSync(dir,{recursive:true,force:true});}
});

test('failed profile write leaves its active endpoint unchanged',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'diakitw-atomic-'));
 try{
  const file=path.join(dir,'profiles.json'),store=new ProfileStore(file),passwords=new Map();
  const base={name:'original',host:'old.example.org',port:22,user:'alice',auth:'password',fingerprint:'SHA256:'+'A'.repeat(43)};
  const saved=saveServerSession(store,passwords,{...base,password:'old-secret'});
  const collision=file+'.'+process.pid+'.tmp';fs.writeFileSync(collision,'do not overwrite');
  assert.throws(()=>saveServerSession(store,passwords,{...saved,host:'new.example.org',fingerprint:'SHA256:'+'B'.repeat(43)}),/EEXIST/);
  assert.equal(store.list()[0].host,base.host,'failed save must not change the live endpoint');
  assert.equal(store.list()[0].fingerprint,base.fingerprint);
  assert.equal(passwords.get(saved.id),'old-secret','old endpoint still owns its credential');
  assert.throws(()=>store.remove(saved.id),/EEXIST/);
  assert.equal(store.list().length,1,'failed remove must not change the live list');
  assert.equal(fs.readFileSync(collision,'utf8'),'do not overwrite');
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});

test('late SSH sample cannot repopulate CPU baseline after endpoint reset',async()=>{
 const key=Buffer.from('test-host-key');const fingerprint='SHA256:'+crypto.createHash('sha256').update(key).digest('base64').replace(/=+$/,'');
 let releaseOld,number=0;
 class SlowClient extends EventEmitter{
  connect(config){queueMicrotask(()=>config.hostVerifier(key)?this.emit('ready'):this.emit('error',Error('bad host')));return this;}
  exec(_command,cb){const stream=new Readable({read(){}});stream.stderr=new Readable({read(){this.push(null)}});cb(null,stream);
   const first=++number===1;stream.push(first?'STAT\ncpu  100 0 0 900 0 0 0 0\nMEM\nDISK\n':'STAT\ncpu  200 0 0 1000 0 0 0 0\nMEM\nDISK\n');
   const complete=()=>stream.push(null);stream.once('end',()=>stream.emit('close',0));if(first)releaseOld=complete;else complete();
  }
  end(){}
 }
 const monitor=new ServerMonitor({client:SlowClient}),p={id:'same-id',name:'server',host:'old.example.org',port:22,user:'alice',auth:'password',fingerprint};
 const pending=monitor.sample(p,'secret');await new Promise(resolve=>setImmediate(resolve));assert.equal(typeof releaseOld,'function');
 monitor.reset(p.id);releaseOld();await assert.rejects(pending,/устарев|изменён/);
 const fromNewEndpoint=await monitor.sample({...p,host:'new.example.org'},'secret');
 assert.equal(fromNewEndpoint.cpu,null,'new endpoint must start with no CPU baseline from the prior host');
});
