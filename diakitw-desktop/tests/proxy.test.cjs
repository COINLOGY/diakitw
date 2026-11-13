'use strict';
const test=require('node:test'),a=require('node:assert/strict');
const {EventEmitter}=require('node:events');
const fixture={ip:'203.0.113.44',city:'Berlin',region:'Berlin',country:'Germany',code:'DE',timezone:'Europe/Berlin',lat:52.5,lon:13.4,asn:{id:64500,name:'Example Network',hosting:false}};
function fake(body){return(url,options,cb)=>{a.equal(url,'https://aia.emcx.pro/diakitw-api/geo');a.equal(options.method,'GET');a.equal(options.agent,false);a.deepEqual(Object.keys(options.headers).sort(),['Accept','Cache-Control']);const req=new EventEmitter();req.destroy=()=>{};req.end=()=>queueMicrotask(()=>{const res=new EventEmitter();res.statusCode=200;res.destroy=()=>{};cb(res);res.emit('data',Buffer.from(JSON.stringify(body)));res.emit('end');});return req;};}
test('2ip via EMCx: fixed no-query no-token endpoint decodes the same IP and nullable geography',async()=>{
 const {lookupGeo}=require('../app/geo.cjs');
 const geo=await lookupGeo(undefined,{request:fake(fixture)});
 a.deepEqual(geo,{ip:fixture.ip,country:'Germany',city:'Berlin',region:'Berlin',code:'DE',timezone:'Europe/Berlin',latitude:52.5,longitude:13.4,asn:fixture.asn});
 for(const body of [{ip:fixture.ip},{...fixture,city:null,region:null,lat:null,lon:null,asn:null}]){const g=await lookupGeo(undefined,{request:fake(body)});a.equal(g.city,null);a.equal(g.latitude,null);a.equal(g.asn,null);}
});

test('proxy rejects malformed typed fields instead of publishing partial or mixed identity',async()=>{
 const {lookupGeo}=require('../app/geo.cjs');
 for(const change of [{ip:'fe80::1%en0'},{country:42},{city:'<script>'},{region:[]},{code:'Germany'},{timezone:'../UTC'},{lat:'52.5'},{lon:181},{lat:91},{asn:[]},{asn:{id:-1,name:'X',hosting:false}},{asn:{id:64500,name:'X',hosting:'yes'}},{asn:{id:64500,name:'<html>',hosting:false}}])await a.rejects(lookupGeo(undefined,{request:fake({...fixture,...change})}),JSON.stringify(change));
});
