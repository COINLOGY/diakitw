const fs=require('node:fs');
const crypto=require('node:crypto');
const {memory,cpuLinux,cpuPercent}=require('./core.cjs');
const COMMAND="LC_ALL=C sh -c 'printf " + '"STAT\\n"; head -n 1 /proc/stat; printf "MEM\\n"; cat /proc/meminfo; printf "DISK\\n"; df -P -B1 /' ;
const empty=()=>({used:null,total:null});
function validateProfile(input){
 const name=String(input?.name||'').trim(),host=String(input?.host||'').trim(),user=String(input?.user||'').trim();
 const port=Number(input?.port),auth=input?.auth,fingerprint=String(input?.fingerprint||'').trim();
 if(!name||name.length>80)throw Error('Укажите название (до 80 символов)');
 if(!host||host.length>253||!(/^[a-z0-9][a-z0-9.-]*$/i.test(host)||/^\[[0-9a-f:]+\]$/i.test(host)))throw Error('Укажите корректный адрес IP или домен');
 if(!Number.isInteger(port)||port<1||port>65535)throw Error('Укажите порт 1–65535');
 if(!/^[a-z_][a-z0-9_.-]{0,63}$/i.test(user))throw Error('Укажите корректный логин');
 if(!['key','password'].includes(auth))throw Error('Выберите ключ или пароль');
 if(!/^SHA256:[A-Za-z0-9+/]{43}$/.test(fingerprint))throw Error('Укажите сверенный SHA256-отпечаток SSH-хоста');
 const keyPath=auth==='key'?String(input.keyPath||'').trim():'';
 if(auth==='key'&&!keyPath)throw Error('Выберите файл закрытого ключа');
 return {name,host,port,user,auth,fingerprint,keyPath};
}
class ProfileStore{
 constructor(file){this.file=file;this.profiles=[];try{const stat=fs.statSync(file);if(stat.size>65536)throw Error('Слишком большой файл профилей');const parsed=JSON.parse(fs.readFileSync(file,'utf8'));if(!Array.isArray(parsed)||parsed.length>16)throw Error('Неверный файл профилей');this.profiles=parsed.map(p=>({id:p.id,...validateProfile(p)}));}catch(e){if(e.code!=='ENOENT')throw e;}}
 list(){return this.profiles.map(p=>({...p}));}
 save(input){const normalized=validateProfile(input);const id=typeof input.id==='string'&&this.profiles.some(p=>p.id===input.id)?input.id:crypto.randomUUID();if(this.profiles.length>=16&&!this.profiles.some(p=>p.id===id))throw Error('Лимит: 16 серверов');const profile={id,...normalized};this.profiles=this.profiles.filter(p=>p.id!==id).concat(profile);this.flush();return {...profile};}
 remove(id){this.profiles=this.profiles.filter(p=>p.id!==id);this.flush();}
 flush(){fs.mkdirSync(require('node:path').dirname(this.file),{recursive:true});const temp=this.file+'.'+process.pid+'.tmp';try{fs.writeFileSync(temp,JSON.stringify(this.profiles),{mode:0o600,flag:'wx'});fs.renameSync(temp,this.file);}finally{try{fs.unlinkSync(temp);}catch{}}}
}
function parseSample(text,previous){const part=(a,b)=>{const start=text.indexOf(a+'\n');if(start<0)return '';const from=start+a.length+1;const end=b?text.indexOf(b+'\n',from):-1;return text.slice(from,end<0?undefined:end);};const stat=part('STAT','MEM').split('\n')[0];const counters=cpuLinux(stat);const mem=memory(part('MEM','DISK'));const row=part('DISK').split('\n').find(l=>/\s+\/\s*$/.test(l));const cols=row?.trim().split(/\s+/)||[];const total=Number(cols[1]),used=Number(cols[2]);const disk=cols.length>=6&&Number.isSafeInteger(total)&&Number.isSafeInteger(used)&&total>0&&used>=0&&used<=total?{used,total}:empty();return {cpu:cpuPercent(previous,counters),ram:mem.ram,swap:mem.swap,disk,counters};}
class ServerMonitor{
 constructor({client}={}){this.Client=client;this.counters=new Map();}
 async sample(profile,password){const Client=this.Client||require('ssh2').Client;let key;if(profile.auth==='key'){key=fs.readFileSync(profile.keyPath);if(key.length>65536)throw Error('Ключ слишком большой');}else if(!password)throw Error('Введите пароль для этого сеанса');
  return new Promise((resolve,reject)=>{const conn=new Client();let settled=false,verified=false,mismatch=false;const done=(err,value)=>{if(settled)return;settled=true;conn.end();if(err)reject(err);else resolve(value);};const timer=setTimeout(()=>done(Error('SSH: время ожидания истекло')),10000);const finish=(err,value)=>{clearTimeout(timer);done(err,value);};
   conn.on('error',e=>finish(Error(mismatch?'Отпечаток SSH-хоста не совпал':`SSH: ${e.message}`)));conn.on('close',()=>{if(!settled)finish(Error('SSH-соединение закрыто'));});conn.on('ready',()=>{if(!verified){finish(Error('Отпечаток SSH-хоста не подтверждён'));return;}conn.exec(COMMAND,(err,stream)=>{if(err){finish(err);return;}let out='',stderr='';stream.on('data',chunk=>{out+=chunk.toString();if(out.length>65536)finish(Error('Ответ SSH слишком большой'));});stream.stderr.on('data',chunk=>{stderr+=chunk.toString().slice(0,1024);});stream.on('error',finish);stream.on('close',code=>{if(settled)return;if(code!==0){finish(Error('Сбор показателей не удался: '+stderr.slice(0,200)));return;}const reading=parseSample(out,this.counters.get(profile.id));this.counters.set(profile.id,reading.counters);delete reading.counters;finish(null,reading);});});});
   conn.connect({host:profile.host.replace(/^\[|\]$/g,''),port:profile.port,username:profile.user,privateKey:key,password:profile.auth==='password'?password:undefined,readyTimeout:8000,hostVerifier:hostKey=>{const actual='SHA256:'+crypto.createHash('sha256').update(hostKey).digest('base64').replace(/=+$/,'');verified=crypto.timingSafeEqual(Buffer.from(actual),Buffer.from(profile.fingerprint));mismatch=!verified;return verified;}});
  });
 }
 reset(id){this.counters.delete(id);}
}
module.exports={ProfileStore,validateProfile,parseSample,ServerMonitor};
