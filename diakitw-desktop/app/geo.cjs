'use strict';
const {isIP}=require('node:net');
function place(v){return typeof v==='string'&&v.length<=100&&/^[\p{L}\p{M} .,'’()&-]+$/u.test(v)&&!/^unknown$/i.test(v)?v.trim()||null:null;}
function coordinate(v,max){if(typeof v==='string'&&!/^-?\d+(\.\d+)?$/.test(v))return null;const n=typeof v==='string'?Number(v):v;return typeof n==='number'&&Number.isFinite(n)&&Math.abs(n)<=max?n:null;}
function parseGeo(body){if(typeof body!=='string'||Buffer.byteLength(body)>16384)throw Error('size');const o=JSON.parse(body);if(!o||Array.isArray(o)||typeof o.ip!=='string'||!/^[0-9a-fA-F:.]+$/.test(o.ip)||!isIP(o.ip))throw Error('invalid');return{ip:o.ip,country:place(o.country),city:place(o.city),latitude:coordinate(o.latitude,90),longitude:coordinate(o.longitude,180)};}
// The proxy returns the egress IP and geography in one response; never join providers.
function parseProxyGeo(body){
 if(typeof body!=='string'||Buffer.byteLength(body)>16384)throw Error('size');
 const o=JSON.parse(body);if(!o||Array.isArray(o)||typeof o!=='object')throw Error('invalid');
 const optional=(v,valid)=>{if(v===undefined||v===null)return null;if(!valid(v))throw Error('invalid');return v;};
 const text=v=>typeof v==='string'&&v.length>0&&v.length<=100&&!/[\x00-\x1f\x7f<>]/u.test(v);
 for(const key of ['country','city','region'])optional(o[key],v=>text(v)&&place(v)!==null);
 for(const [key,max] of [['lat',90],['lon',180]])optional(o[key],v=>typeof v==='number'&&Number.isFinite(v)&&Math.abs(v)<=max);
 const code=optional(o.code,v=>typeof v==='string'&&/^[A-Z]{2}$/.test(v));
 const timezone=optional(o.timezone,v=>typeof v==='string'&&v.length<=100&&/^[A-Za-z_+-]+(?:\/[A-Za-z0-9_+-]+)*$/.test(v));
 let asn=null;if(o.asn!==undefined&&o.asn!==null){if(typeof o.asn!=='object'||Array.isArray(o.asn))throw Error('invalid');asn={id:optional(o.asn.id,v=>(Number.isSafeInteger(v)&&v>=0&&v<=4294967295)||(typeof v==='string'&&/^(?:AS)?\d{1,10}$/.test(v)&&Number(v.replace(/^AS/,''))<=4294967295)),name:optional(o.asn.name,text),hosting:optional(o.asn.hosting,v=>typeof v==='boolean')};}
 const normalized=parseGeo(JSON.stringify({ip:o.ip,country:o.country,city:o.city,latitude:o.lat,longitude:o.lon}));
 return {...normalized,region:o.region??null,code,timezone,asn};
}
function mapURL(geo){if(!geo)return null;const u=new URL('https://www.openstreetmap.org/');if(place(geo.city)&&typeof geo.latitude==='number'&&coordinate(geo.latitude,90)!==null&&typeof geo.longitude==='number'&&coordinate(geo.longitude,180)!==null){u.searchParams.set('mlat',String(geo.latitude));u.searchParams.set('mlon',String(geo.longitude));u.hash='map=8/'+geo.latitude+'/'+geo.longitude;}else if(place(geo.country)){u.pathname='/search';u.searchParams.set('query',place(geo.country));}else return null;return u.href;}
function lookupGeo(signal,{request=require('node:https').request,timeout=5000}={}){
 return new Promise((resolve,reject)=>{
  let req,res,timer,done=false;
  const finish=(error,value)=>{if(done)return;done=true;clearTimeout(timer);signal?.removeEventListener('abort',abort);if(error){res?.destroy();req?.destroy();reject(error);}else resolve(value);};
  const abort=()=>finish(Error('cancelled'));
  if(signal?.aborted){reject(Error('cancelled'));return;}
  try{
   req=request('https://aia.emcx.pro/diakitw-api/geo',{method:'GET',agent:false,headers:{Accept:'application/json','Cache-Control':'no-store'}},response=>{
    if(done){response.destroy();return;}res=response;
    res.on('error',()=>finish(Error('network')));res.on('aborted',()=>finish(Error('network')));
    if(res.statusCode!==200){finish(Error('http'));return;}
    const chunks=[];let size=0;
    res.on('data',chunk=>{if(done)return;const b=Buffer.from(chunk);size+=b.length;if(size>16384){finish(Error('size'));return;}chunks.push(b);});
    res.on('end',()=>{if(done)return;try{finish(null,parseProxyGeo(Buffer.concat(chunks).toString('utf8')));}catch{finish(Error('invalid'));}});
   });
   req.on('error',()=>finish(Error('network')));signal?.addEventListener('abort',abort,{once:true});timer=setTimeout(()=>finish(Error('timeout')),timeout);req.end();
  }catch{finish(Error('network'));}
 });
}
module.exports={parseGeo,parseProxyGeo,mapURL,lookupGeo};
