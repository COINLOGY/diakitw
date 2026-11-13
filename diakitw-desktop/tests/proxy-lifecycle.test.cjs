'use strict';
const test=require('node:test'),a=require('node:assert/strict');
const {Egress}=require('../app/egress.cjs');const flush=()=>new Promise(r=>setImmediate(r));
const geo={ip:'203.0.113.44',country:'Germany',city:'Berlin',region:'Berlin',code:'DE',timezone:'Europe/Berlin',latitude:52,longitude:13,asn:{id:64500,name:'Example',hosting:false}};
test('atomic egress keeps metadata for this IP and clears all geography on IP-only replacement',async()=>{
 let now=0,value=geo;const e=new Egress({automatic:false,clock:()=>now,lookup:async()=>value});e.start();await flush();a.equal(e.state.asn.name,'Example');a.equal(e.state.code,'DE');a.equal(e.state.region,'Berlin');
 value='2001:db8::7';now=60000;await e.tick();for(const key of ['country','city','region','code','timezone','latitude','longitude','asn'])a.equal(e.state[key],null,key);a.equal(e.state.ip,value);a.equal(e.state.status,'current');e.stop();
});
test('route change aborts obsolete request, stale failure cannot publish, refocus retains cooldown',async()=>{
 let now=0,finish,reject,signal,calls=0;const states=[];const e=new Egress({automatic:false,clock:()=>now,publish:s=>states.push(s),lookup:s=>{signal=s;calls++;return new Promise((r,j)=>{finish=r;reject=j;});}});e.start();e.observe('eth0');e.observe('vpn');a.equal(signal.aborted,true);const count=states.length;reject(Error('old'));await flush();a.equal(states.length,count);now=9999;await e.tick();a.equal(calls,1);now=10000;e.tick();finish(geo);await flush();a.equal(e.state.ip,geo.ip);e.stop();e.start();await e.tick();a.equal(calls,2);e.stop();
});
