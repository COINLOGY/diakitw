const {isIP}=require('node:net');
function parseIP(body){if(typeof body!=='string'||Buffer.byteLength(body)>128)throw Error('invalid');const ip=body.trim();if(!/^[0-9a-fA-F:.]+$/.test(ip)||!isIP(ip))throw Error('invalid');return ip;}
function lookupIP(signal,{request=require('node:https').request,timeout=5000}={}){
 return new Promise((resolve,reject)=>{let req,timer,done=false;const finish=(error,value)=>{if(done)return;done=true;clearTimeout(timer);signal?.removeEventListener('abort',abort);error?reject(error):resolve(value);};const abort=()=>{const e=Error('cancelled');req?.destroy(e);finish(e);};if(signal?.aborted){finish(Error('cancelled'));return;}
 try{req=request('https://api.ipify.org/',{method:'GET',agent:false,headers:{Accept:'text/plain','Cache-Control':'no-store'}},res=>{if(done){res.destroy();return;}if(res.statusCode!==200){res.destroy();finish(Error('http'));return;}let body='',bytes=0;res.on('data',chunk=>{bytes+=chunk.length;if(bytes>128){res.destroy();req.destroy();finish(Error('size'));}else body+=chunk.toString('utf8');});res.on('error',e=>finish(e));res.on('end',()=>{try{finish(null,parseIP(body));}catch(e){finish(e);}});});req.on('error',e=>finish(e));signal?.addEventListener('abort',abort,{once:true});timer=setTimeout(()=>{const e=Error('timeout');req.destroy(e);finish(e);},timeout);req.end();}catch(e){finish(e);}
 });
}
async function lookupEgress(signal,{geo=require('./geo.cjs').lookupGeo,fallback=lookupIP}={}){
 if(signal?.aborted)throw Error('cancelled');
 try{return await geo(signal);}catch{if(signal?.aborted)throw Error('cancelled');return fallback(signal);}
}
class Egress{
 constructor({lookup=lookupIP,publish=()=>{},clock=()=>performance.now(),automatic=true}={}){Object.assign(this,{lookup,publish,clock,automatic,active:false,busy:false,generation:0,revision:0,last:-Infinity,due:Infinity,state:{status:'unknown',ip:null,checkedAt:null}});}
 emit(status,extra={}){this.state={...this.state,status,...extra};this.publish(this.state);}
 start(){if(this.active)return;this.active=true;this.generation++;this.due=this.clock();this.tick();if(this.automatic)this.timer=setInterval(()=>this.tick(),1000);}
 stop(){this.active=false;this.generation++;clearInterval(this.timer);this.controller?.abort();this.emit(this.state.ip?'stale':'unknown');}
 observe(key){if(typeof key!=='string'||key===this.key)return;const first=this.key===undefined;this.key=key;if(first)return;this.revision++;this.controller?.abort();this.emit(this.state.ip?'stale':'unknown');this.due=Math.min(this.due,this.clock()+2000);this.changed=this.clock();}
 async tick(){const now=this.clock();if(!this.active||this.busy||now<this.due||now-this.last<10000||now-(this.changed??-Infinity)<2000)return;this.busy=true;this.last=now;this.due=now+60000;const g=this.generation,r=this.revision;this.controller=new AbortController();this.emit(this.state.ip?'stale':'loading');try{const value=await this.lookup(this.controller.signal);const input=typeof value==='string'?{ip:parseIP(value)}:{...value,lat:value.latitude,lon:value.longitude};const geo=require('./geo.cjs').parseProxyGeo(JSON.stringify(input));if(this.active&&g===this.generation&&r===this.revision)this.emit('current',{...geo,checkedAt:Date.now()});}catch{if(this.active&&g===this.generation&&r===this.revision)this.emit(this.state.ip?'stale':'failed');}finally{this.busy=false;}}
}
module.exports={parseIP,lookupIP,lookupEgress,Egress};
