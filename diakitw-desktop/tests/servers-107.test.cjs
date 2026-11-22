const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const os=require('node:os');
const crypto=require('node:crypto');
const {EventEmitter}=require('node:events');
const {Readable}=require('node:stream');
const {ProfileStore,parseSample,ServerMonitor,validateProfile}=require('../app/servers.cjs');

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
