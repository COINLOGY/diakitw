const test=require('node:test'),assert=require('node:assert/strict');
const {EventEmitter}=require('node:events');
test('Geo transport fixed HTTPS, byte/redirect/time bounds and late callback abort',async()=>{
 const {lookupGeo}=require('../app/geo.cjs');assert.equal(typeof lookupGeo,'function');
 for(const mode of ['success','redirect','size','timeout','cancel']){let callback,destroyed=0;const ac=new AbortController();const request=(url,options,cb)=>{assert.equal(url,'https://aia.emcx.pro/diakitw-api/geo');assert.equal(options.agent,false);assert.equal(options.headers.Cookie,undefined);callback=cb;const req=new EventEmitter();req.destroy=()=>{destroyed++};req.end=()=>{if(mode==='timeout'||mode==='cancel')return;queueMicrotask(()=>{const res=new EventEmitter();res.statusCode=mode==='redirect'?302:200;res.destroy=()=>{};cb(res);res.emit('data',Buffer.from(mode==='size'?'x'.repeat(16385):'{"ip":"2001:db8::1","country":"Germany"}'));res.emit('end');});};return req;};const p=lookupGeo(ac.signal,{request,timeout:10});if(mode==='cancel'){ac.abort();const late=new EventEmitter();late.destroy=()=>{destroyed++};callback(late);}if(mode==='success')assert.equal((await p).country,'Germany');else await assert.rejects(p);if(['cancel','timeout'].includes(mode))assert.ok(destroyed>0);}
});
test('foreground egress publishes geodata atomically and suppresses cancelled geo',async()=>{const {Egress}=require('../app/egress.cjs');let finish;const e=new Egress({automatic:false,lookup:()=>new Promise(r=>finish=r)});e.start();finish({ip:'2001:db8::1',country:'Germany',city:'Berlin',latitude:52,longitude:13});await new Promise(r=>setImmediate(r));assert.equal(e.state.country,'Germany');assert.equal(e.state.city,'Berlin');e.stop();assert.equal(e.state.status,'stale');});
test('GeoJS IPv6 country city and bounded malformed fields; safe OSM URL',()=>{
 const {parseGeo,mapURL}=require('../app/geo.cjs');
 const geo=parseGeo(JSON.stringify({ip:'2001:db8::1',country:'Germany',city:'Berlin',latitude:'52.5',longitude:'13.4'}));
 assert.equal(geo.ip,'2001:db8::1');assert.equal(geo.city,'Berlin');
 const u=new URL(mapURL(geo));assert.equal(u.origin,'https://www.openstreetmap.org');assert.equal(u.searchParams.get('mlat'),'52.5');
 const country=parseGeo('{"ip":"203.0.113.1","country":"A & B","latitude":"0","longitude":"0"}');assert.equal(country.city,null);assert.equal(new URL(mapURL(country)).searchParams.get('query'),'A & B');
 for(const bad of ['{}','[]','null','{"ip":"1.2.3.4;rm"}','x'.repeat(16385)])assert.throws(()=>parseGeo(bad));
 const invalid=parseGeo('{"ip":"1.2.3.4","city":"<script>","latitude":"Infinity","longitude":2}');assert.equal(invalid.city,null);assert.equal(mapURL(invalid),null);
 for(const lat of [NaN,Infinity,91,null,'0'])assert.equal(mapURL({latitude:lat,longitude:0,city:'X'}),null);
 assert.equal(mapURL({country:'javascript:alert(1)'}),null);
});
