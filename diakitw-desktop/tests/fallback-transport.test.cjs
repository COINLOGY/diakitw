const test=require('node:test'),a=require('node:assert/strict'),{EventEmitter}=require('node:events');
test('cancelled IP fallback destroys a late response without consuming it',async()=>{
 const {lookupIP}=require('../app/egress.cjs');let callback,requestsDestroyed=0,responsesDestroyed=0;const request=(_u,_o,cb)=>{callback=cb;const req=new EventEmitter();req.end=()=>{};req.destroy=()=>{requestsDestroyed++};return req;};
 const ac=new AbortController();const p=lookupIP(ac.signal,{request,timeout:50});ac.abort();await a.rejects(p);const res=new EventEmitter();res.statusCode=200;res.destroy=()=>{responsesDestroyed++};callback(res);a.equal(requestsDestroyed,1);a.equal(responsesDestroyed,1);a.equal(res.listenerCount('data'),0);
});
