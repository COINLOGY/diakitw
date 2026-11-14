'use strict';
const https=require('node:https');
const ENDPOINT='https://coinlogy.github.io/diakitw/updates/v1.json';
const platforms=['macos-arm64','macos-x86_64','windows-x64','linux-x64','android'];
function version(v){if(typeof v!=='string'||!/^(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})$/.test(v))throw Error('version');return v.split('.').map(Number);}
function compare(a,b){const x=version(a),y=version(b);for(let i=0;i<3;i++)if(x[i]!==y[i])return x[i]-y[i];return 0;}
function asset(a,v){const prefix=`https://github.com/COINLOGY/diakitw/releases/download/v${v}/`;if(!a||typeof a.url!=='string'||!a.url.startsWith(prefix)||!/^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/.test(a.url.slice(prefix.length))||a.url.slice(prefix.length).includes('..')||!Number.isSafeInteger(a.size)||a.size<=0||a.size>8589934592||typeof a.sha256!=='string'||!(/^[a-f0-9]{64}$/).test(a.sha256))throw Error('asset');return a;}
function select(text,platform,channel,current='0.5.4',build=54){
 if(Buffer.byteLength(text)>32768||!platforms.includes(platform)||!['stable','preview'].includes(channel))throw Error('manifest');
 const m=JSON.parse(text);if(m.schema!==1||!Array.isArray(m.releases)||m.releases.length>64)throw Error('schema');let chosen=null;
 for(const r of m.releases){version(r.version);if(!Number.isSafeInteger(r.build)||r.build<1||r.build>2147483647||!['stable','preview'].includes(r.channel)||typeof r.notes!=='string'||r.notes.length>4096||!r.assets||Array.isArray(r.assets))throw Error('release');
 for(const [p,a] of Object.entries(r.assets)){if(!platforms.includes(p))throw Error('platform');asset(a,r.version);}
 if(r.channel!==channel||!r.assets[platform]||compare(r.version,current)<=0||(platform==='android'&&r.build<=build))continue;
 if(!chosen||compare(r.version,chosen.version)>0)chosen={version:r.version,build:r.build,notes:r.notes,asset:r.assets[platform]};
 }return chosen;
}
function fetchManifest(signal){return new Promise((resolve,reject)=>{let bytes=0,chunks=[],done=false;const finish=(err,value)=>{if(done)return;done=true;clearTimeout(timer);err?reject(err):resolve(value);};
 const request=https.get(ENDPOINT,{signal,agent:false,headers:{Accept:'application/json','Accept-Encoding':'identity'}},response=>{if(response.statusCode!==200){response.resume();request.destroy();finish(Error('HTTP'));return;}response.on('data',chunk=>{bytes+=chunk.length;if(bytes>32768){request.destroy();finish(Error('size'));}else chunks.push(chunk);});response.on('end',()=>finish(null,Buffer.concat(chunks).toString('utf8')));response.on('error',e=>finish(e));});
 const timer=setTimeout(()=>{request.destroy();finish(Error('timeout'));},10000);request.on('error',e=>finish(e));
 });}
class Checker{
 constructor({platform,state={},save=()=>{},notify=()=>{},fetch=fetchManifest,now=Date.now}){Object.assign(this,{platform,save,notify,fetch,now});this.state={channel:state.channel==='stable'?'stable':'preview'};for(const k of ['success','attempt','failure'])this.state[k]=Number.isFinite(state[k])&&state[k]>0&&state[k]<=now()?state[k]:0;this.active=false;this.busy=false;this.generation=0;}
 start(){if(this.active)return;this.active=true;this.ready=this.now()+3000;this.timer=setInterval(()=>{void this.check(false);},3000);this.timer.unref?.();}
 stop(){this.active=false;this.generation++;clearInterval(this.timer);this.controller?.abort();}
 channel(value){if(!['stable','preview'].includes(value)||value===this.state.channel)return;const active=this.active;this.stop();this.state.channel=value;this.state.success=0;this.save(this.state);if(active)this.start();}
 async check(manual){const n=this.now();if(!this.active||this.busy)return false;if((this.state.attempt&&n-this.state.attempt<60000)||(!manual&&(n<this.ready||(this.state.success&&n-this.state.success<86400000)||(this.state.failure&&n-this.state.failure<3600000)))){if(manual)this.notify({status:'throttled'});return false;}
 this.busy=true;const gen=this.generation;this.state.attempt=n;this.save(this.state);this.controller=new AbortController();try{const text=await this.fetch(this.controller.signal);const release=select(text,this.platform,this.state.channel);if(!this.active||gen!==this.generation)return false;this.state.success=this.now();this.state.failure=0;this.save(this.state);if(release||manual)this.notify({status:release?'available':'current',release});return true;}catch(_){if(this.active&&gen===this.generation){this.state.failure=this.now();this.save(this.state);if(manual)this.notify({status:'error'});}return false;}finally{this.busy=false;}
 }
}
module.exports={ENDPOINT,version,compare,asset,select,fetchManifest,Checker};
