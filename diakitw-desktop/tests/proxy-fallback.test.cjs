const test=require('node:test'),a=require('node:assert/strict');
test('fallback runs only after geo failure, never after cancellation or valid nullable geo',async()=>{
 const {lookupEgress}=require('../app/egress.cjs');a.equal(typeof lookupEgress,'function');let fallbacks=0;const fallback=async()=>{fallbacks++;return '2001:db8::7';};const success={ip:'203.0.113.1',country:null};a.equal(await lookupEgress(undefined,{geo:async()=>success,fallback}),success);a.equal(fallbacks,0);
 a.equal(await lookupEgress(undefined,{geo:async()=>{throw Error('private upstream detail')},fallback}),'2001:db8::7');a.equal(fallbacks,1);
 const ac=new AbortController();await a.rejects(lookupEgress(ac.signal,{geo:async()=>{ac.abort();throw Error('cancelled')},fallback}));a.equal(fallbacks,1);
 await a.rejects(lookupEgress(ac.signal,{geo:async()=>{throw Error('must not run')},fallback}));a.equal(fallbacks,1);
});
